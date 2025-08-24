import 'dart:async';
import 'package:bcalio/widgets/chat/chat_room/call_sounds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:flutter/services.dart'; // 👈 MethodChannel (ui_accept / ui_reject)

import '../../../controllers/user_controller.dart';
import '../../../services/webrtccontroller.dart';

/* ---- Journal d’appel ---- */
import '../../../controllers/call_log_controller.dart';
import '../../../models/call_log_model.dart';

class AudioCallScreen extends StatefulWidget {
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

  // 👇 flag pour gérer l’accept côté destinataire (cas autoAccept)
  final bool shouldSendLocalAccept;

  const AudioCallScreen({
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
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen>
    with SingleTickerProviderStateMixin {

  static const _platform = MethodChannel('incoming_calls'); // 👈

  bool _micOn      = true;
  bool _speakerOn  = true;
  bool _show       = true;
  bool _sent       = false;        // pour l’appelant
  bool _acceptSent = false;        // destinataire (local accept)

  // ⬇️ Anti-doublons / contrôle de fin locale
  bool _handledTerminal = false;
  bool _locallyEnded    = false;
  bool _endSignaled     = false;

  // ⬇️ Marquage natif (empêche “missed” tardifs côté Android)
  bool _nativeAcceptMarked  = false;
  bool _nativeRejectMarked  = false;

  late final AnimationController _anim;
  late final Animation<double>   _scale;

  late final WebRTCController _rtc;

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
    _rtc = WebRTCController(
      baseUrl  : 'http://192.168.1.12:1906',
      callId   : '${me.userId}_${_isGroup ? 'group' : widget.recipientID}',
      selfName : me.userName,
      withVideo: false,
    )..onInit();
    _rtc.attachSocket(me.socketService);

    // toasts groupe pour l’appelant
    if (_isGroup && widget.isCaller) {
      _rtc.onUiParticipantJoined = (uid, name) =>
          _toast('${name.isNotEmpty ? name : uid} a rejoint l’appel');
      _rtc.onUiParticipantTimeout = (_) {};
    }

    final sock = me.socketService;

    sock.onCallInitiated = (cid) {
      if (_callId == null && mounted) setState(() => _callId = cid);
    };

    // APPELANT : émet l’appel + ringback + fallback timeout
    if (widget.isCaller && !_sent) {
      _sent = true;
      CallSounds.playRingBack();

      if (_isGroup) {
        final members = List<String>.from(widget.memberIds ?? const []);
        sock.initiateGroupCall(widget.userId, members, me.userName, 'audio');
      } else {
        sock.initiateCall(widget.userId, widget.recipientID, me.userName, 'audio');
      }

      _fallbackTimeout?.cancel();
      _fallbackTimeout = Timer(const Duration(seconds: 32), () {
        if (!mounted || _start != null || _handledTerminal) return;
        CallSounds.stopRingBack();
        _handledTerminal = true;
        _showBanner('Ne répond pas', Colors.orange);
        _finishAfterBeep(() => CallSounds.playEndBeep());
        _log(CallStatus.timeout);

        // annuler côté serveur pour fermer l’écran chez B
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

    // DESTINATAIRE : prépare la vue; compteur démarre quand "call-accepted"
    if (!widget.isCaller && widget.existingCallId != null) {
      _callId = widget.existingCallId;
      _start  = null;
      if (!_isGroup) {
        _rtc.addPeer(widget.recipientID, widget.name, initiator: false);
      }
    }

    // === listeners AVANT tout accept local ===
    sock.onCallAccepted = (cid) {
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      if (mounted) {
        setState(() {
          _callId = cid;
          _start  = DateTime.now();
        });
      }

      // 👇 Marque "accepted" côté Android pour (A et B)
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

    sock.onCallRejected  = () {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();

      // 👇 Marque "rejected" pour empêcher un "missed" parasite côté A
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

      _showBanner('Occupé', Colors.red);
      _finishAfterBeep(() => CallSounds.playBusyOnce());
      _log(CallStatus.rejected);
    };

    sock.onCallEnded     = () {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      _showBanner('Appel terminé', Colors.white70);
      _finishAfterBeep(() => CallSounds.playEndBeep());
      _log(CallStatus.ended, endedAt: DateTime.now());
    };

    sock.onCallCancelled = () {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      if (mounted) Get.back();
      _log(CallStatus.cancelled);
    };

    sock.onCallError     = (_) {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      if (mounted) Get.back();
    };

    sock.onCallTimeout   = () {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      _showBanner('Ne répond pas', Colors.orange);
      _finishAfterBeep(() => CallSounds.playEndBeep());
      _log(CallStatus.timeout);
    };

    // 👇 destinataire auto-accept (depuis notif plein écran)
    if (!widget.isCaller && widget.shouldSendLocalAccept && !_acceptSent) {
      _acceptSent = true;
      final idToAccept = widget.existingCallId ?? '${widget.userId}_${_isGroup ? "group" : widget.recipientID}';

      // marque "accepted" immédiatement côté Android (coupe notif/alarme s’il en reste)
      try { _platform.invokeMethod('ui_accept', {'callId': idToAccept}); } catch (_) {}

      sock.acceptCall(idToAccept, widget.userId);
    }

    rtc.Helper.setSpeakerphoneOn(true);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_start != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _fallbackTimeout?.cancel();
    CallSounds.stopRingBack();
    rtc.Helper.setSpeakerphoneOn(false);

    // n’émettre endCall qu’en cas de raccrochage local et si pas déjà envoyé
    if (_locallyEnded && _callId != null && !_endSignaled) {
      try { Get.find<UserController>().socketService.endCall(_callId!); } catch (_) {}
    }

    _rtc.leave();
    _anim.dispose();
    super.dispose();
  }

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
    if (mounted) Get.back();
  }

  String _fmt() {
    if (_start == null) return '00:00';
    final d = DateTime.now().difference(_start!);
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _log(CallStatus status, {DateTime? endedAt}) async {
    try {
      final ctrl = Get.find<CallLogController>();
      final callId = _callId ?? '${widget.userId}_${_isGroup ? 'group' : widget.recipientID}';
      final dir    = widget.isCaller ? CallDirection.outgoing : CallDirection.incoming;
      final type   = CallType.audio;
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
    final dark = Theme.of(ctx).brightness == Brightness.dark;

    return Scaffold(
      body: GestureDetector(
        onTap: _toggle,
        child: Stack(children: [
          // renderers audio (cachés)
          Obx(() => Stack(
                children: _rtc.participants.map((p) {
                  return Offstage(
                    offstage: true,
                    child: rtc.RTCVideoView(p.renderer),
                  );
                }).toList(),
              )),

          Positioned.fill(
              child: Image.asset(
                dark ? 'assets/chat_bg_dark.png'
                     : 'assets/chat_bg_light.png',
                fit: BoxFit.cover,
              )),
          Positioned.fill(
              child: Container(color: Colors.black.withOpacity(dark ? .7 : .4))),

          _avatar(),
          _infos(),
          _controls(),
        ]),
      ),
    );
  }

  Widget _infos() => AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        top: _show ? 80 : 40,
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
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(_start == null ? 'Calling…' : (_isGroup ? 'In group call…' : 'In call…'),
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 10),
              Text(_fmt(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  Widget _controls() => AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        bottom: _show ? 60 : -100,
        left: 0,
        right: 0,
        child: ScaleTransition(
          scale: _scale,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _btn(Iconsax.volume_high,
                    active: _speakerOn,
                    onTap: () {
                      setState(() {
                        _speakerOn = !_speakerOn;
                        rtc.Helper.setSpeakerphoneOn(_speakerOn);
                      });
                    }),
                _btn(_micOn ? Iconsax.microphone
                             : Iconsax.microphone_slash,
                    active: _micOn, onTap: () {
                  setState(() => _micOn = !_micOn);
                  _rtc.toggleMic();
                }),
                _btn(Iconsax.call_slash, bg: Colors.red, onTap: _hangUp),
              ],
            ),
          ),
        ),
      );

  void _hangUp() {
    final sock = Get.find<UserController>().socketService;

    _fallbackTimeout?.cancel();
    CallSounds.stopRingBack();

    // marque la fin locale et bloque les prochains events terminaux
    _locallyEnded  = true;
    _handledTerminal = true;

    if (_start == null) {
      _log(CallStatus.cancelled);
      if (_callId != null) {
        sock.cancelCall(_callId!, widget.userId);
      } else if (!_isGroup) {
        sock.cancelCall('${widget.userId}_${widget.recipientID}', widget.userId);
      }
    } else {
      _log(CallStatus.ended, endedAt: DateTime.now());
      if (_callId != null) {
        sock.endCall(_callId!);
        _endSignaled = true; // évite un second endCall en dispose
      }
    }
    Get.back();
  }

  Widget _btn(IconData icon,
          {Color bg = const Color(0x33FFFFFF),
          bool active = true,
          required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(
            icon,
            color: bg == Colors.red
                ? Colors.white
                : active
                    ? Colors.white
                    : Colors.red,
            size: 28,
          ),
        ),
      );

  Widget _avatar() => Center(
        child: CircleAvatar(
          radius: 70,
          backgroundColor: Colors.white.withOpacity(.1),
          backgroundImage: (widget.avatarUrl ?? '').isNotEmpty
              ? NetworkImage(widget.avatarUrl!)
              : null,
          child: (widget.avatarUrl ?? '').isEmpty
              ? const Icon(Iconsax.user, size: 60, color: Colors.white)
              : null,
        ),
      );
}
