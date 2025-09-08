// lib/modules/roomkit/webrtc_controller.dart
import 'dart:async';
import 'dart:collection';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'socket_service.dart';
import 'participant.dart';

String _ts() => DateTime.now().toIso8601String().substring(11, 23);
void _log(String m) => print('[${_ts()}][WRTC] $m');

class _Peer {
  rtc.RTCPeerConnection pc;
  final bool initiator;
  bool makingOffer = false;
  bool polite = false;
  bool haveRemote = false;
  final List<rtc.RTCIceCandidate> pendingIce = [];
  Timer? answerWatchdog;

  _Peer({required this.pc, required this.initiator});
}

class WebRTCController extends GetxController {
  final String roomId, displayName;
  WebRTCController({required this.roomId, required this.displayName});

  final participants = <Participant>[].obs;
  final micOn = true.obs, camOn = true.obs;

  rtc.MediaStream? _local;
  final _peers = HashMap<String, _Peer>();
  late SocketService _sock;
  String selfId = '';

  Future<void> onInit() async {
    _log('onInit() → getUserMedia');
    try {
      _local = await rtc.navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user'},
      });
      participants.add(Participant(id: 'self', displayName: displayName, stream: _local));
    } catch (e) {
      _log('getUserMedia ERROR: $e');
    }
  }

  void attachSocket(SocketService sock) {
    _sock = sock;
    selfId = sock.id;

    // ✅ bind explicite et robuste (ne pourra plus être écrasé)
    _sock.setRtcHandlers(
      onOffer:  _handleOffer,
      onAnswer: _handleAnswer,
      onIce:    _handleIce,
    );
  }

  Future<void> addPeer(String id, String name) async {
    if (_peers.containsKey(id)) return;

    final my = (_sock.id.isNotEmpty) ? _sock.id : selfId;
    final initiator = my.isNotEmpty ? (my.compareTo(id) < 0) : (displayName.compareTo(name) < 0);
    final polite    = my.isNotEmpty ? (my.compareTo(id) > 0) : (displayName.compareTo(name) > 0);

    final pc = await _createPC(id);
    final peer = _Peer(pc: pc, initiator: initiator)..polite = polite;
    _peers[id] = peer;

    participants.add(Participant(id: id, displayName: name));

    if (initiator) await _makeOffer(id, pc, peer);
  }

  void removePeer(String id) {
    _peers[id]?.answerWatchdog?.cancel();
    _peers[id]?.pc.close();
    _peers.remove(id);
    participants.removeWhere((p) => p.id == id);
  }

  void toggleMic() {
    micOn.toggle();
    _local?.getAudioTracks().forEach((t) => t.enabled = micOn.value);
  }

  void toggleCam() {
    camOn.toggle();
    _local?.getVideoTracks().forEach((t) => t.enabled = camOn.value);
  }

  void leave() {
    _local?.getTracks().forEach((t) { try { t.stop(); } catch (_) {} });
    _local?.dispose();
    for (final p in _peers.values) {
      p.answerWatchdog?.cancel();
      p.pc.close();
    }
    _peers.clear();
    participants.clear();
  }

  Future<rtc.RTCPeerConnection> _createPC(String remoteId) async {
    final pc = await rtc.createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        // 🔁 Besoin de TURN hors-LAN ? ajoute ici :
        // {'urls': 'turn:YOUR_TURN_IP:3478', 'username': 'user', 'credential': 'pass'},
      ],
      'sdpSemantics': 'unified-plan',
    });

    // On ajoute UNIQUEMENT nos tracks locales (pas de transceiver explicite).
    if (_local != null) {
      for (final t in _local!.getTracks()) {
        try { await pc.addTrack(t, _local!); } catch (e) { _log('addTrack error: $e'); }
      }
    }

    pc.onTrack = (evt) {
      final p = participants.firstWhereOrNull((e) => e.id == remoteId);
      if (p != null) {
        p.stream = evt.streams.isNotEmpty ? evt.streams.first : null;
        participants.refresh();
      }
    };

    pc.onIceCandidate = (c) {
      if (c != null) _sock.emitIce(remoteId, c.toMap());
    };

    pc.onConnectionState = (s) {
      _log('[$remoteId] PC state → $s');
      if (s == rtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        pc.restartIce();
      }
    };

    pc.onSignalingState = (s) {
      _log('[$remoteId] signaling → $s');
    };

    return pc;
  }

  Future<void> _makeOffer(String remoteId, rtc.RTCPeerConnection pc, _Peer peer, {bool retry=false}) async {
    try {
      peer.makingOffer = true;
      final offer = await pc.createOffer({});
      await pc.setLocalDescription(offer);
      final desc = await pc.getLocalDescription();
      if (desc != null) {
        _log('→ emit offer to=$remoteId type=${desc.type}');
        _sock.emitOffer(remoteId, desc.toMap());
      }
      peer.answerWatchdog?.cancel();
      peer.answerWatchdog = Timer(const Duration(seconds: 6), () async {
        if (pc.signalingState == rtc.RTCSignalingState.RTCSignalingStateHaveLocalOffer && !retry) {
          _log('answer watchdog → retry offer');
          await _makeOffer(remoteId, pc, peer, retry: true);
        }
      });
    } catch (e) {
      _log('_makeOffer ERROR: $e');
    } finally {
      peer.makingOffer = false;
    }
  }

  Future<void> _handleOffer(String from, Map sdp) async {
    _log('← handle OFFER from=$from');
    var peer = _peers[from];
    if (peer == null) {
      final pc = await _createPC(from);
      peer = _Peer(pc: pc, initiator: false);
      _peers[from] = peer;
      participants.add(Participant(id: from, displayName: ''));

      final myId = (_sock.id.isNotEmpty) ? _sock.id : selfId;
      peer.polite = myId.isNotEmpty ? (myId.compareTo(from) > 0) : true;
    }
    var pc = peer.pc;

    final stable = pc.signalingState == rtc.RTCSignalingState.RTCSignalingStateStable;
    final glare = peer.makingOffer || !stable;

    if (glare && !peer.polite) {
      _log('glare & impolite → ignore offer');
      return;
    }

    if (!stable) {
      try {
        await pc.setLocalDescription(rtc.RTCSessionDescription('', 'rollback'));
      } catch (e) {
        _log('rollback unsupported → recreate PC: $e');
        try { await pc.close(); } catch (_) {}
        final newPc = await _createPC(from);
        peer.pc = newPc;
        pc = newPc;
      }
    }

    try {
      await pc.setRemoteDescription(rtc.RTCSessionDescription(
        sdp['sdp'].toString(),
        sdp['type'].toString().toLowerCase(),
      ));
      peer.haveRemote = true;
    } catch (e) {
      _log('setRemoteDescription(offer) ERROR: $e');
      return;
    }

    while (peer.pendingIce.isNotEmpty) {
      final c = peer.pendingIce.removeAt(0);
      try { await pc.addCandidate(c); } catch (e) { _log('flush ICE error: $e'); }
    }

    try {
      final answer = await pc.createAnswer({});
      await pc.setLocalDescription(answer);
      final desc = await pc.getLocalDescription();
      if (desc != null) {
        _log('→ emit ANSWER to=$from type=${desc.type}');
        _sock.emitAnswer(from, desc.toMap());
      }
    } catch (e) {
      _log('create/setLocal answer ERROR: $e');
    }
  }

  Future<void> _handleAnswer(String from, Map sdp) async {
    _log('← handle ANSWER from=$from');
    final peer = _peers[from];
    final pc = peer?.pc;
    if (pc == null) return;

    peer?.answerWatchdog?.cancel();

    try {
      await pc.setRemoteDescription(rtc.RTCSessionDescription(
        sdp['sdp'].toString(),
        sdp['type'].toString().toLowerCase(),
      ));
      if (peer != null) peer.haveRemote = true;
    } catch (e) {
      _log('setRemoteDescription(answer) ERROR: $e');
      return;
    }

    while (peer!.pendingIce.isNotEmpty) {
      final c = peer.pendingIce.removeAt(0);
      try { await pc.addCandidate(c); } catch (e) { _log('flush ICE (post-answer) error: $e'); }
    }
  }

  Future<void> _handleIce(String from, Map ice) async {
    final peer = _peers[from];
    final pc = peer?.pc;
    if (pc == null || peer == null) return;

    final cand = rtc.RTCIceCandidate(
      (ice['candidate'] ?? '').toString(),
      ice['sdpMid']?.toString(),
      ice['sdpMLineIndex'] is String ? int.tryParse(ice['sdpMLineIndex']) ?? 0 : (ice['sdpMLineIndex'] as int? ?? 0),
    );

    if (peer.haveRemote) {
      try { await pc.addCandidate(cand); } catch (e) { _log('addCandidate ERROR: $e'); }
    } else {
      peer.pendingIce.add(cand);
    }
  }
}
