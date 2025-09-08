import 'dart:async';

import 'package:bcalio/widgets/chat/chat_room/VideoTile.dart';
import 'package:bcalio/widgets/chat/chat_room/call_sounds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:collection/collection.dart';

import '../../../controllers/user_controller.dart';
import '../../../services/webrtccontroller.dart';

/* ---- Journal d’appel ---- */
import '../../../controllers/call_log_controller.dart';
import '../../../models/call_log_model.dart';

/* ✅ Session globale d'appel : mini-barre + restauration */
import '../../../controllers/call_session_controller.dart';

class VideoCallScreen extends StatefulWidget {
  final String name;
  final String? avatarUrl;
  final String phoneNumber;
  final String recipientID;   // 1:1 uniquement
  final String userId;
  final bool   isCaller;
  final String? existingCallId;

  // Groupe
  final bool isGroup;
  final List<String>? memberIds; // sans moi

  // autoAccept
  final bool shouldSendLocalAccept;

  // restauration
  final bool isRestored;

  const VideoCallScreen({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.phoneNumber,
    required this.recipientID,
    required this.userId,
    required this.isCaller,
    required this.existingCallId,
    this.isGroup = false,
    this.memberIds,
    this.shouldSendLocalAccept = false,
    this.isRestored = false,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with SingleTickerProviderStateMixin {

  static const _platform = MethodChannel('incoming_calls'); // Android notifications

  final CallSessionController _sess = Get.find<CallSessionController>();
  bool _reuseRtc = false;

  bool _micOn     = true,
       _camOn     = true,
       _speakerOn = true,
       _show      = true,
       _sent      = false;

  bool _acceptSent = false;

  bool _handledTerminal = false;
  bool _locallyEnded    = false;
  bool _endSignaled     = false;

  bool _nativeAcceptMarked = false;
  bool _nativeRejectMarked = false;

  bool   _peerOnline   = true;
  bool   _videoHealthy = true;
  bool   _linkDown     = false;
  DateTime? _linkDownSince;
  String? _statusHint;

  late final AnimationController _anim;
  late final Animation<double>   _scale;

  late WebRTCController _rtc;

  String?   _callId;
  DateTime? _start;
  late final Timer _ticker;

  Timer? _fallbackTimeout;

  bool get _isGroup => widget.isGroup == true;

  @override
  void initState() {
    super.initState();

    _anim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();

    final me = Get.find<UserController>();

    // ✅ réutiliser le RTC vidéo UNIQUEMENT si restauration d'un appel EN COURS
    if (widget.isRestored &&
        _sess.rtc != null &&
        _sess.isVideo.value == true &&
        _sess.isOngoing.value) {
      _rtc = _sess.rtc!;
      _reuseRtc = true;
      _start = _sess.startedAt;
    } else {
      _rtc = WebRTCController(
        baseUrl  : 'http://192.168.1.22:1906',
        callId   : '${me.userId}_${_isGroup ? 'group' : widget.recipientID}',
        selfName : me.userName,
        withVideo: true,
      )..onInit();
      _rtc.attachSocket(me.socketService);
    }

    // ✅ bind métadonnées + attache RTC à la session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sess.bindMeta(
        displayName: widget.name,
        avatar:      widget.avatarUrl,
        meId:        widget.userId,
        peerId:      _isGroup ? '' : widget.recipientID,
        caller:      widget.isCaller,
        group:       _isGroup,
        members:     List<String>.from(widget.memberIds ?? const []),
        cid:         widget.existingCallId,
      );
      if (!_reuseRtc) _sess.attachRtc(_rtc, video: true);
    });

    // Toasts UI (appelant en groupe)
    if (_isGroup && widget.isCaller) {
      _rtc.onUiParticipantJoined  = (uid, name) =>
          _toast('${name.isNotEmpty ? name : uid} ${'a rejoint l’appel'.tr}');
      _rtc.onUiParticipantTimeout = (_) {};
    }

    final sock = me.socketService;

    /* === Reprise réseau/peer -> renégociation === */
    sock.onLinkDown = (cid) {
      if (_start == null) return;
      _statusHint = 'Problème de connexion… Reconnexion en cours'.tr;
      if (mounted) setState(() {});
      _showBanner('Problème de connexion chez ${widget.name}'.tr, Colors.orange);
    };

    sock.onLinkUp = (cid) async {
      if (_start == null) return;
      _peerOnline = true;
      _statusHint = 'Connexion rétablie'.tr;
      if (mounted) setState(() {});
      _showBanner('Connexion rétablie'.tr, Colors.greenAccent);
      await _rtc.renegotiateAll();
    };

    sock.onPeerSuspended = (cid, uid) {
      if (_isGroup) return;
      if (uid != widget.recipientID) return;
      _peerOnline = false;
      _refreshLinkHealth(showBanner: true, force: true);
    };

    sock.onPeerResumed = (cid, uid) async {
      if (_isGroup) return;
      if (uid != widget.recipientID) return;
      _peerOnline = true;
      _statusHint = 'Connexion rétablie'.tr;
      if (mounted) setState(() {});
      _showBanner('Connexion rétablie'.tr, Colors.greenAccent);
      await _rtc.renegotiateAll();
    };

    // listeners AVANT émission
    sock.onPresenceUpdate = (uid, online, lastSeen) {
      if (_isGroup) return;
      final other = widget.recipientID;
      if (uid != other) return;
      if (_start == null) return;
      final wasOnline = _peerOnline;
      _peerOnline = online;
      _refreshLinkHealth(showBanner: true, force: wasOnline != online);
    };

    sock.onCallInitiated = (cid) {
      if (_callId == null && mounted) setState(() => _callId = cid);
    };

    sock.onCallAccepted = (cid) {
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      if (_start == null && mounted) {
        setState(() {
          _callId = cid;
          _start  = DateTime.now();
          _statusHint = null;
        });
      }

      _sess.markAcceptedNow();

      if (!_nativeAcceptMarked) {
        _nativeAcceptMarked = true;
        final idToMark = (cid.isNotEmpty)
            ? cid
            : (widget.existingCallId ?? '${widget.userId}_${_isGroup ? "group" : widget.recipientID}');
        try { _platform.invokeMethod('ui_accept', {'callId': idToMark}); } catch (_) {}
      }

      if (!_isGroup) {
        _rtc.addPeer(widget.recipientID, widget.name, initiator: widget.isCaller);
      }

      _log(CallStatus.accepted);
    };

    sock.onCallRejected = () {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();

      if (!_nativeRejectMarked) {
        _nativeRejectMarked = true;
        final idToMark = _callId ?? widget.existingCallId ?? '${widget.userId}_${_isGroup ? "group" : widget.recipientID}';
        try {
          _platform.invokeMethod('ui_reject', {
            'callId'    : idToMark,
            'callerId'  : widget.userId,
            'callerName': widget.name,
            'avatarUrl' : widget.avatarUrl ?? '',
          });
        } catch (_) {}
      }

      _showBanner('Occupé'.tr, Colors.red);
      _finishAfterBeep(() => CallSounds.playBusyOnce());
      _log(CallStatus.rejected);

      _sess.clearSession(disposeRtc: true); // 👈
    };

    sock.onCallEnded = () {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      _showBanner('Appel terminé'.tr, Colors.white70);
      _finishAfterBeep(() => CallSounds.playEndBeep());
      _log(CallStatus.ended, endedAt: DateTime.now());

      _sess.clearSession(disposeRtc: true); // 👈
    };

    sock.onCallCancelled = () {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      _safePop();
      _log(CallStatus.cancelled);

      _sess.clearSession(disposeRtc: true); // 👈
    };

    sock.onCallError = (_) {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      _safePop();

      _sess.clearSession(disposeRtc: true); // 👈
    };

    sock.onCallTimeout = () {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      _showBanner('Ne répond pas'.tr, Colors.orange);
      _finishAfterBeep(() => CallSounds.playEndBeep());
      _log(CallStatus.timeout);

      _sess.clearSession(disposeRtc: true); // 👈
    };

    // DESTINATAIRE : préconfig (attend l’offer entrant)
    if (!widget.isCaller && widget.existingCallId != null) {
      _callId = widget.existingCallId;
      if (!_isGroup) {
        _rtc.addPeer(widget.recipientID, widget.name, initiator: false);
      }
    }

    // APPELANT : émettre APRÈS listeners (pas en restauration)
    if (widget.isCaller && !_sent && !widget.isRestored) {
      _sent = true;
      CallSounds.playRingBack();

      if (_isGroup) {
        final members = List<String>.from(widget.memberIds ?? const []);
        sock.initiateGroupCall(widget.userId, members, me.userName, 'video');
      } else {
        sock.initiateCall(widget.userId, widget.recipientID, me.userName, 'video');
      }

      _fallbackTimeout?.cancel();
      _fallbackTimeout = Timer(const Duration(seconds: 32), () {
        if (!mounted || _start != null || _handledTerminal) return;
        CallSounds.stopRingBack();
        _handledTerminal = true;
        _showBanner('Ne répond pas'.tr, Colors.orange);
        _finishAfterBeep(() => CallSounds.playEndBeep());
        _log(CallStatus.timeout);

        try {
          final s = Get.find<UserController>().socketService;
          if (_callId != null) {
            s.cancelCall(_callId!, widget.userId);
          } else if (!_isGroup) {
            s.cancelCall('${widget.userId}_${widget.recipientID}', widget.userId);
          }
        } catch (_) {}
      });
    }

    // destinataire auto-accept
    if (!widget.isCaller && widget.shouldSendLocalAccept && !_acceptSent) {
      _acceptSent = true;
      final idToAccept = widget.existingCallId ?? '${widget.userId}_${_isGroup ? "group" : widget.recipientID}';

      try { _platform.invokeMethod('ui_accept', {'callId': idToAccept}); } catch (_) {}
      sock.acceptCall(idToAccept, widget.userId);
    }

    rtc.Helper.setSpeakerphoneOn(_speakerOn);

    // ⏱ Ticker: chrono + santé vidéo
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_start != null) setState(() {});
      _evaluateVideoHealth();
    });
  }

  @override
  void dispose() {
    _ticker.cancel();

    final keepMedia = _sess.isOngoing.value &&
                      _sess.isMinimized.value &&
                      _sess.rtc == _rtc;

    if (!keepMedia) {
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      rtc.Helper.setSpeakerphoneOn(false);

      if (_locallyEnded && _callId != null && !_endSignaled) {
        try { Get.find<UserController>().socketService.endCall(_callId!); } catch (_) {}
      }

      _rtc.leave();
    }

    _anim.dispose();
    super.dispose();
  }

  void _safePop() {
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  /* ───────────────────── Santé média & bannières ───────────────────── */

  void _evaluateVideoHealth() {
    final others = _rtc.participants.where((p) => p.id != 'self').toList();
    final hasRemoteVideo = others.any((p) => p.stream != null);

    final wasHealthy = _videoHealthy;
    _videoHealthy = hasRemoteVideo;

    if (_start == null) return;

    if (wasHealthy != _videoHealthy) {
      _refreshLinkHealth(showBanner: true, force: true);
    } else {
      _refreshLinkHealth(showBanner: false);
    }
  }

  void _refreshLinkHealth({required bool showBanner, bool force = false}) {
    final wasDown = _linkDown;
    _linkDown = !(_peerOnline && _videoHealthy);

    if (!force && wasDown == _linkDown) return;

    if (_linkDown) {
      _linkDownSince ??= DateTime.now();
      _statusHint = 'Problème de connexion… Reconnexion en cours'.tr;
      if (showBanner) _showBanner('Problème de connexion chez ${widget.name}'.tr, Colors.orange);
    } else {
      _linkDownSince = null;
      _statusHint = 'Connexion rétablie'.tr;
      if (showBanner) _showBanner('Connexion rétablie'.tr, Colors.greenAccent);
    }
    if (mounted) setState(() {});
  }

  /* ───────────────────── UI helpers ───────────────────── */

  void _toggle() => setState(() => _show = !_show);

  void _toast(String text) {
    if (!mounted) return;
    Get.snackbar(
      '',
      text,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.black.withOpacity(.7),
      colorText: Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      duration: const Duration(milliseconds: 1200),
    );
  }

  void _showBanner(String text, Color color) {
    if (!mounted) return;
    Get.snackbar(
      '',
      text,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.black87,
      colorText: color,
      duration: const Duration(milliseconds: 900),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _finishAfterBeep(Future<void> Function() sound) async {
    try { await sound(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 900));
    _safePop();
  }

  String _fmt() {
    if (_start == null) return '00:00';
    final d = DateTime.now().difference(_start!);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _log(CallStatus status, {DateTime? endedAt}) async {
    try {
      final ctrl = Get.find<CallLogController>();
      final callId = _callId ?? '${widget.userId}_${_isGroup ? 'group' : widget.recipientID}';
      final dir    = widget.isCaller ? CallDirection.outgoing : CallDirection.incoming;
      final type   = CallType.video;
      final duration = (endedAt != null && _start != null)
          ? endedAt.difference(_start!).inSeconds
          : 0;

      await ctrl.upsert(CallLog(
        callId: callId,
        peerId: widget.isCaller ? (_isGroup ? 'group' : widget.recipientID) : widget.userId,
        peerName: widget.name,
        peerAvatar: widget.avatarUrl,
        direction: dir,
        type: type,
        status: status,
        startedAt: _start ?? DateTime.now(),
        endedAt: endedAt,
        durationSeconds: duration,
      ));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext ctx) {
    return WillPopScope(
      onWillPop: () async {
        // ↩️ BACK système → minimiser (pas de flèche retour)
        _sess.minimizeAndHideUI(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggle,
          child: Stack(children: [

            /* flux vidéo */
            Positioned.fill(
              child: Obx(() {
                final others = _rtc.participants.where((p) => p.id != 'self').toList();

                if (!_isGroup) {
                  final r = others.isNotEmpty ? others.first : null;
                  return VideoTile(
                    id: r?.id ?? widget.recipientID,
                    name: r?.displayName ?? widget.name,
                    stream: r?.stream,
                    isSelf: false,
                  );
                }

                return _buildGroupLayout(others);
              }),
            ),

            /* PiP local */
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              top: _show ? 60 : 20,
              right: _show ? 20 : 10,
              child: _pip(),
            ),

            /* infos */
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              top: _show ? 60 : 30,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _show ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Column(
                  children: [
                    Text(widget.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(_fmt(),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 16)),
                  ],
                ),
              ),
            ),

            /* badge état réseau/média */
            if (_start != null && _statusHint != null)
              Positioned(
                left: 16, right: 16, bottom: 110,
                child: Center(
                  child: AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusHint!,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),

            /* boutons */
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              bottom: _show ? 40 : -100,
              left: 0,
              right: 0,
              child: ScaleTransition(
                scale: _scale,
                child: _controls(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /* ───────────── layout groupe ───────────── */
  Widget _buildGroupLayout(List others) {
    final n = others.length;
    if (n == 0) {
      return Center(
        child: Text('Waiting for participants…'.tr, style: const TextStyle(color: Colors.white70)),
      );
    }
    if (n == 1) {
      final r = others.first;
      return VideoTile(id: r.id, name: r.displayName, stream: r.stream, isSelf: false);
    }
    if (n == 2) {
      return Column(
        children: [
          Expanded(child: Padding(
            padding: const EdgeInsets.all(6),
            child: VideoTile(id: others[0].id, name: others[0].displayName, stream: others[0].stream),
          )),
          Expanded(child: Padding(
            padding: const EdgeInsets.all(6),
            child: VideoTile(id: others[1].id, name: others[1].displayName, stream: others[1].stream),
          )),
        ],
      );
    }
    if (n == 3) {
      return Column(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: VideoTile(id: others[0].id, name: others[0].displayName, stream: others[0].stream),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Expanded(child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: VideoTile(id: others[1].id, name: others[1].displayName, stream: others[1].stream),
                )),
                Expanded(child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: VideoTile(id: others[2].id, name: others[2].displayName, stream: others[2].stream),
                )),
              ],
            ),
          ),
        ],
      );
    }
    if (n == 4) {
      return GridView.builder(
        padding: const EdgeInsets.all(6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 9/16),
        itemCount: 4,
        itemBuilder: (_, i) => VideoTile(
          id: others[i].id, name: others[i].displayName, stream: others[i].stream),
      );
    }
    if (n <= 6) {
      return GridView.builder(
        padding: const EdgeInsets.all(6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 9/16),
        itemCount: n,
        itemBuilder: (_, i) => VideoTile(
          id: others[i].id, name: others[i].displayName, stream: others[i].stream),
      );
    }
    if (n <= 9) {
      return GridView.builder(
        padding: const EdgeInsets.all(6),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 9/16),
        itemCount: n,
        itemBuilder: (_, i) => VideoTile(
          id: others[i].id, name: others[i].displayName, stream: others[i].stream),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(6),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 9/16),
      itemCount: n,
      itemBuilder: (_, i) => VideoTile(
        id: others[i].id, name: others[i].displayName, stream: others[i].stream),
    );
  }

  /* ───────────── PiP local ───────────── */
  Widget _pip() => Container(
        width: 120,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Obx(() {
            final local =
                _rtc.participants.firstWhereOrNull((p) => p.id == 'self');
            return VideoTile(
              id: 'self',
              name: local?.displayName ?? 'Me'.tr,
              stream: local?.stream,
              isSelf: true,
            );
          }),
        ),
      );

  /* ───────────── contrôles ───────────── */
  Widget _controls() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _btn(_micOn ? Iconsax.microphone : Iconsax.microphone_slash, () {
              setState(() => _micOn = !_micOn);
              _rtc.toggleMic();
            }),
            _btn(Iconsax.rotate_left, () {
              // TODO : switch caméra si besoin
            }),
            _btn(_speakerOn ? Iconsax.speaker : Iconsax.speaker4, () {
              setState(() => _speakerOn = !_speakerOn);
              rtc.Helper.setSpeakerphoneOn(_speakerOn);
            }),
            _btn(_camOn ? Iconsax.video : Iconsax.video_slash, () {
              setState(() => _camOn = !_camOn);
              _rtc.toggleCam();
            }),
            _btn(Iconsax.call_slash, _hangUp, bg: Colors.red),
          ],
        ),
      );

  void _hangUp() {
    final sock = Get.find<UserController>().socketService;

    _fallbackTimeout?.cancel();
    CallSounds.stopRingBack();

    _locallyEnded    = true;
    _handledTerminal = true;

    if (_start == null) {
      _log(CallStatus.cancelled);
      if (_callId != null) {
        sock.cancelCall(_callId!, widget.userId);
      } else if (!_isGroup) {
        final provisionalId = '${widget.userId}_${widget.recipientID}';
        sock.cancelCall(provisionalId, widget.userId);
      }
    } else {
      _log(CallStatus.ended, endedAt: DateTime.now());
      if (_callId != null) {
        sock.endCall(_callId!);
        _endSignaled = true;
      }
    }

    _sess.clearSession(disposeRtc: true); // 👈
    _safePop();
  }

  Widget _btn(IconData icon, VoidCallback onTap, {Color bg = const Color(0x33FFFFFF)}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      );
}
