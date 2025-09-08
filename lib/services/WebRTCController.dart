import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:collection/collection.dart'; // firstWhereOrNull

import 'socket_service.dart';
import '../models/participant.dart';

/// ───────────────────── VIDEO / AUDIO CALL CONTROLLER ─────────────────────
class WebRTCController extends GetxController {
  final String baseUrl;
  final String callId;
  final String selfName;
  final bool   withVideo;

  WebRTCController({
    required this.baseUrl,
    required this.callId,
    required this.selfName,
    required this.withVideo,
  });

  /* ---------------- reactive state (UI) ---------------- */
  final participants = <Participant>[].obs; // self + remotes
  final micOn = true.obs;
  final camOn = true.obs;

  /* ---------------- UI hooks (optionnels) ---------------- */
  void Function(String userId, String name)? onUiParticipantJoined;
  void Function(String userId)? onUiParticipantLeft;
  void Function(String userId)? onUiParticipantTimeout;

  /* ---------------- internals ---------------- */
  late SocketService  _sock;
  late String         _selfId;
  rtc.MediaStream?    _local;
  final _peers = HashMap<String, rtc.RTCPeerConnection>(); // remoteId → pc

  // Perfect negotiation
  final _makingOffer = <String, bool>{};
  final _polite      = <String, bool>{}; // callee = polite, caller = impolite

  // Anti-rafale renégo
  bool _renoBusy = false;

  /* ───────────────────────── INIT ───────────────────────── */
  @override
  Future<void> onInit() async {
    super.onInit();

    _local = await rtc.navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': withVideo ? {'facingMode': 'user'} : false,
    });
    debugPrint('[RTC] local stream ready ${_local?.id}');

    final me = Participant(id: 'self', displayName: selfName, stream: _local);
    await me.renderer.initialize();
    me.renderer.srcObject = _local;
    participants.add(me);
  }

  void attachSocket(SocketService sock) {
    _sock   = sock;
    _selfId = sock.userId;

    sock
      ..onOffer              = _onOffer
      ..onAnswer             = _onAnswer
      ..onIce                = _onIce
      // Groupe
      ..onParticipants       = _onParticipants
      ..onParticipantJoined  = _onParticipantJoined
      ..onParticipantLeft    = _onParticipantLeft
      ..onParticipantTimeout = _onParticipantTimeout;
  }

  /* ───────────────────────── helpers UI ───────────────────────── */
  void toggleMic() =>
      _local?.getAudioTracks().forEach((t) => t.enabled = micOn.toggle().value);

  void toggleCam() {
    if (!withVideo) return;
    _local?.getVideoTracks().forEach((t) => t.enabled = camOn.toggle().value);
  }

  void leave() {
    // Stoppe & libère tout proprement
    try {
      for (final t in _local?.getTracks() ?? const []) {
        try { t.stop(); } catch (_) {}
      }
    } catch (_) {}
    try { _local?.dispose(); } catch (_) {}
    _local = null; // 👈 important : empêche toute réutilisation

    for (final p in participants) {
      p.renderer.srcObject = null;
      try { p.renderer.dispose(); } catch (_) {}
    }

    for (final pc in _peers.values) {
      try { pc.close(); } catch (_) {}
    }
    _peers.clear();
    participants.clear();

    _makingOffer.clear();
    _polite.clear();
  }

  /* ───────────────────── MULTI-PEER (mesh) ───────────────────── */

  void _onParticipants(String callId, List<Map<String, String>> list) async {
    for (final u in list) {
      final uid = u['userId'] ?? '';
      final nm  = u['name']   ?? uid;
      if (uid.isEmpty || uid == _selfId) continue;
      await addPeer(uid, nm, initiator: true);   // le joiner envoie les OFFERS
    }
  }

  void _onParticipantJoined(String callId, String userId, String name) async {
    if (userId.isEmpty || userId == _selfId) return;
    await addPeer(userId, name.isNotEmpty ? name : userId, initiator: false); // attendre l'offer
    onUiParticipantJoined?.call(userId, name.isNotEmpty ? name : userId);
  }

  void _onParticipantLeft(String callId, String userId) {
    if (userId.isEmpty) return;
    final pc = _peers.remove(userId);
    try { pc?.close(); } catch (_) {}
    final idx = participants.indexWhere((p) => p.id == userId);
    if (idx >= 0) {
      final p = participants.removeAt(idx);
      p.renderer.srcObject = null;
      p.renderer.dispose();
    }
    onUiParticipantLeft?.call(userId);
  }

  void _onParticipantTimeout(String callId, String userId) {
    onUiParticipantTimeout?.call(userId);
  }

  /* ───────────────────── ADD / JOIN PEER ───────────────────── */
  Future<void> addPeer(
    String remoteId,
    String remoteName, {
    required bool initiator,
  }) async {
    if (remoteId == _selfId) return;
    if (_peers.containsKey(remoteId)) return;

    final pc = await _createPC(remoteId, initiator: initiator);
    _peers[remoteId] = pc;

    // caller = impolite, callee = polite
    _polite[remoteId] = !initiator;

    final remote = Participant(id: remoteId, displayName: remoteName);
    await remote.renderer.initialize();
    participants.add(remote);

    debugPrint('[RTC] addPeer $remoteId  initiator=$initiator');

    if (initiator) {
      await _ensureLocalTracks(pc);
      final offer = await _safeCreateOffer(pc, remoteId);
      await pc.setLocalDescription(offer);
      _sock.emitOffer(remoteId, offer.toMap());
      debugPrint('[RTC] → OFFER to $remoteId');
    }
  }

  /* ─────────────────── PEER-CONNECTION factory ─────────────────── */
  Future<rtc.RTCPeerConnection> _createPC(
    String remoteId, {
    required bool initiator,
  }) async {
    const bool forceRelay = false;

    final pc = await rtc.createPeerConnection({
      'iceServers': [
        { 'urls': ['stun:fr-turn3.xirsys.com'] },
        {
          'urls': [
            'turn:fr-turn3.xirsys.com:80?transport=udp',
            'turn:fr-turn3.xirsys.com:3478?transport=udp',
            'turn:fr-turn3.xirsys.com:80?transport=tcp',
            'turn:fr-turn3.xirsys.com:3478?transport=tcp',
            'turns:fr-turn3.xirsys.com:443?transport=tcp',
            'turns:fr-turn3.xirsys.com:5349?transport=tcp',
          ],
          'username': 'oOk-ca-e8130Y5GOX_DTijaY3lpYLXkH8ecECdK_e_VBpGN6eQ9cJaansd7UkQ3DAAAAAGiuNflCQ2FsaW8=',
          'credential': '8aa96840-82cc-11f0-97ad-e25abca605ee',
        },
      ],
      'bundlePolicy': 'max-bundle',
      'rtcpMuxPolicy': 'require',
      'iceTransportPolicy': forceRelay ? 'relay' : 'all',
    });

    if (initiator) {
      pc.addTransceiver(
        kind: rtc.RTCRtpMediaType.RTCRtpMediaTypeAudio,
        init: rtc.RTCRtpTransceiverInit(direction: rtc.TransceiverDirection.SendRecv),
      );
      if (withVideo) {
        pc.addTransceiver(
          kind: rtc.RTCRtpMediaType.RTCRtpMediaTypeVideo,
          init: rtc.RTCRtpTransceiverInit(direction: rtc.TransceiverDirection.SendRecv),
        );
      }
    }

    pc.onTrack = (evt) {
      final user = participants.firstWhereOrNull((p) => p.id == remoteId);
      if (user != null) {
        user.stream = evt.streams.first;
        user.renderer.srcObject = user.stream;
        participants.refresh();
      }
    };

    pc.onIceCandidate = (c) {
      if (c != null) _sock.emitIce(remoteId, c.toMap());
    };

    pc.onConnectionState = (s) {
      debugPrint('[RTC] PC[$remoteId] = $s');
      if (s == rtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        try { pc.restartIce(); } catch (_) {}
      }
    };

    return pc;
  }

  /* ───── Tracks locales: réacquérir si null + replaceTrack si besoin ───── */
  Future<void> _ensureLocalTracks(rtc.RTCPeerConnection pc) async {
    // 👇 Ré-acquiert si on a été libéré par un précédent leave()
    if (_local == null) {
      _local = await rtc.navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': withVideo ? {'facingMode': 'user'} : false,
      });

      // rattache/assure le participant self
      var self = participants.firstWhereOrNull((p) => p.id == 'self');
      if (self == null) {
        self = Participant(id: 'self', displayName: selfName);
        await self.renderer.initialize();
        participants.add(self);
      }
      self.stream = _local;
      self.renderer.srcObject = _local;
      participants.refresh();
    }

    final senders = await pc.getSenders();
    final haveAudio = senders.any((s) => s.track?.kind == 'audio');
    final haveVideo = senders.any((s) => s.track?.kind == 'video');

    final localAudio = _local!.getAudioTracks().firstOrNull;
    final localVideo = withVideo ? _local!.getVideoTracks().firstOrNull : null;

    for (final s in senders) {
      if (s.track?.kind == 'audio' && localAudio != null && s.track?.id != localAudio.id) {
        await s.replaceTrack(localAudio);
      }
      if (s.track?.kind == 'video' && localVideo != null && s.track?.id != localVideo.id) {
        await s.replaceTrack(localVideo);
      }
    }

    if (!haveAudio && localAudio != null) {
      await pc.addTrack(localAudio, _local!);
    }
    if (withVideo && !haveVideo && localVideo != null) {
      await pc.addTrack(localVideo, _local!);
    }

    // Optionnel : forcer SendRecv
    try {
      final transceivers = await pc.getTransceivers();
      for (final t in transceivers) {
        try { await (t as dynamic).setDirection(rtc.TransceiverDirection.SendRecv); } catch (_) {}
      }
    } catch (_) {}
  }

  /* ─────────────────── Offer sûre (marqueur makingOffer) ─────────────────── */
  Future<rtc.RTCSessionDescription> _safeCreateOffer(
    rtc.RTCPeerConnection pc,
    String remoteId, { Map<String, dynamic>? options }
  ) async {
    _makingOffer[remoteId] = true;
    try {
      return await pc.createOffer(options ?? <String, dynamic>{});
    } finally {
      _makingOffer[remoteId] = false;
    }
  }

  /* ───────────────────── SIGNALISATION handlers ───────────────────── */

  // Perfect negotiation (anti-glare)
  Future<void> _onOffer(String from, Map s) async {
    debugPrint('[RTC] ← OFFER from $from');

    if (!_peers.containsKey(from)) {
      await addPeer(from, from, initiator: false);
    }
    final pc = _peers[from]!;

    final making   = _makingOffer[from] == true;
    final stable   = pc.signalingState == rtc.RTCSignalingState.RTCSignalingStateStable;
    final collision = making || !stable;
    final polite   = _polite[from] ?? true;

    if (collision && !polite) {
      debugPrint('[RTC] glare: ignore offer from $from (impolite)');
      return;
    }

    if (collision && polite) {
      try {
        await pc.setLocalDescription(rtc.RTCSessionDescription('', 'rollback'));
      } catch (_) {}
    }

    await pc.setRemoteDescription(rtc.RTCSessionDescription(s['sdp'], 'offer'));
    await _ensureLocalTracks(pc);

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    _sock.emitAnswer(from, answer.toMap());
    debugPrint('[RTC] → ANSWER to $from');
  }

  Future<void> _onAnswer(String from, Map s) async {
    debugPrint('[RTC] ← ANSWER from $from');
    final pc = _peers[from];
    if (pc == null) return;

    final state = pc.signalingState;
    if (state != rtc.RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
      return; // hors séquence, ignorer
    }

    await pc.setRemoteDescription(rtc.RTCSessionDescription(s['sdp'], 'answer'));
  }

  Future<void> _onIce(String from, Map c) async {
    final pc = _peers[from];
    if (pc == null) return;
    await pc.addCandidate(
      rtc.RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
    );
  }

  /* ─────────── Renégo à la reprise (ICE restart + anti-rafale) ─────────── */
  Future<void> renegotiateAll() async {
    if (_renoBusy) return; // anti-rafale
    _renoBusy = true;
    try {
      for (final entry in _peers.entries) {
        final remoteId = entry.key;
        final pc = entry.value;

        try {
          await _ensureLocalTracks(pc);

          try { await pc.restartIce(); } catch (_) {}

          final offer = await _safeCreateOffer(pc, remoteId, options: {
            'iceRestart': true,
            'offerToReceiveAudio': 1,
            'offerToReceiveVideo': withVideo ? 1 : 0,
          });

          await pc.setLocalDescription(offer);
          _sock.emitOffer(remoteId, offer.toMap());
          debugPrint('[RTC] renegotiate → OFFER (iceRestart) to $remoteId');
        } catch (e) {
          debugPrint('[RTC] renegotiate $remoteId error: $e');
        }
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () => _renoBusy = false);
    }
  }
}
