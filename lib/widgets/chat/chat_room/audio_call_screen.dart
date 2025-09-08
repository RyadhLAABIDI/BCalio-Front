import 'dart:async';
import 'package:bcalio/widgets/chat/chat_room/call_sounds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:flutter/services.dart';

import '../../../controllers/user_controller.dart';
import '../../../services/webrtccontroller.dart';

/* ---- Journal d’appel ---- */
import '../../../controllers/call_log_controller.dart';
import '../../../models/call_log_model.dart';

/* ✅ Session globale d'appel : mini-barre + restauration */
import '../../../controllers/call_session_controller.dart';

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

  // auto-accept
  final bool shouldSendLocalAccept;

  // restauration depuis mini-barre
  final bool isRestored;

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
    this.isRestored = false,
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen>
    with SingleTickerProviderStateMixin {

  static const _platform = MethodChannel('incoming_calls');

  final CallSessionController _sess = Get.find<CallSessionController>();
  bool _reuseRtc = false;

  bool _micOn      = true;
  bool _speakerOn  = true;
  bool _show       = true;
  bool _sent       = false;
  bool _acceptSent = false;

  bool _handledTerminal = false;
  bool _locallyEnded    = false;
  bool _endSignaled     = false;

  bool _nativeAcceptMarked  = false;
  bool _nativeRejectMarked  = false;

  bool   _peerOnline      = true;
  bool   _mediaHealthy    = true;
  bool   _linkDown        = false;
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

  void _safePop() {
    if (!mounted) return;
    try {
      final nav = Navigator.of(context, rootNavigator: true);
      if (nav.canPop()) nav.pop();
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();

    _anim  = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _anim.forward();

    final me = Get.find<UserController>();

    // ✅ réutilisation RTC UNIQUEMENT si restauration d'un appel EN COURS
    if (widget.isRestored &&
        _sess.rtc != null &&
        _sess.isVideo.value == false &&
        _sess.isOngoing.value) {
      _rtc = _sess.rtc!;
      _reuseRtc = true;
      _start = _sess.startedAt; // ← reprend le chrono depuis la session
    } else {
      _rtc = WebRTCController(
        baseUrl  : 'http://192.168.1.22:1906',
        callId   : '${me.userId}_${_isGroup ? 'group' : widget.recipientID}',
        selfName : me.userName,
        withVideo: false,
      )..onInit();
      _rtc.attachSocket(me.socketService);
    }

    // bind méta + attache RTC à la session
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
      if (!_reuseRtc) _sess.attachRtc(_rtc, video: false);
    });

    // toasts groupe (appelant)
    if (_isGroup && widget.isCaller) {
      _rtc.onUiParticipantJoined = (uid, name) =>
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

    // présence socket du pair
    sock.onPresenceUpdate = (uid, online, lastSeen) {
      final other = widget.recipientID;
      if (_isGroup || uid != other) return;
      if (_start == null) return;
      final wasOnline = _peerOnline;
      _peerOnline = online;
      _refreshLinkHealth(showBanner: true, force: wasOnline != online);
    };

    sock.onCallInitiated = (cid) {
      if (_callId == null && mounted) setState(() => _callId = cid);
    };

    // APPELANT : émettre (pas en restauration)
    if (widget.isCaller && !_sent && !widget.isRestored) {
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
          _statusHint = null;
        });
      }
      _sess.markAcceptedNow(); // ← important pour la mini-barre & la restauration

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

    sock.onCallEnded     = () {
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
      if (mounted) _safePop();
      _log(CallStatus.cancelled);

      _sess.clearSession(disposeRtc: true); // 👈
    };

    sock.onCallError     = (_) {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      if (mounted) _safePop();

      _sess.clearSession(disposeRtc: true); // 👈
    };

    sock.onCallTimeout   = () {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      _showBanner('Ne répond pas'.tr, Colors.orange);
      _finishAfterBeep(() => CallSounds.playEndBeep());
      _log(CallStatus.timeout);

      _sess.clearSession(disposeRtc: true); // 👈
    };

    // =========================
    // 🟢 DESTINATAIRE : auto-accept
    // =========================
    if (!widget.isCaller && widget.shouldSendLocalAccept && !_acceptSent) {
      _acceptSent = true;
      final idToAccept = widget.existingCallId ?? '${widget.userId}_${_isGroup ? "group" : widget.recipientID}';
      try { _platform.invokeMethod('ui_accept', {'callId': idToAccept}); } catch (_) {}
      sock.acceptCall(idToAccept, widget.userId);

      // ⭐ FIX: démarrage local immédiat (au cas où l’event réseau tarde)
      _start ??= DateTime.now();
      _sess.markAcceptedNow();
      setState(() {}); // rafraîchit l’UI tout de suite
    }

    rtc.Helper.setSpeakerphoneOn(true);

    // ⭐ filet de sécu : si déjà accepté mais pas d’event reçu
    if (!widget.isCaller && (widget.existingCallId != null || widget.shouldSendLocalAccept)) {
      if (_sess.startedAt == null) _sess.markAcceptedNow();
      _start ??= _sess.startedAt;
    }

    // ⏱ Ticker: chrono + santé média
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_start != null) setState(() {});
      _evaluateMediaHealth();
    });
  }

  @override
  void dispose() {
    _ticker.cancel();

    // garde le média actif si minimisé
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

  /* ───────────────────── Santé média & bannières ───────────────────── */

  void _evaluateMediaHealth() {
    final others = _rtc.participants.where((p) => p.id != 'self').toList();
    final hasRemote = others.any((p) => p.stream != null);

    final wasHealthy = _mediaHealthy;
    _mediaHealthy = hasRemote;

    if (_start == null || _isGroup) return;

    if (wasHealthy != _mediaHealthy) {
      _refreshLinkHealth(showBanner: true, force: true);
    } else {
      _refreshLinkHealth(showBanner: false);
    }
  }

  void _refreshLinkHealth({required bool showBanner, bool force = false}) {
    final wasDown = _linkDown;
    _linkDown = !(_peerOnline && _mediaHealthy);

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
    if (mounted) _safePop();
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

    return WillPopScope(
      onWillPop: () async {
        // ↩️ BACK système → on minimise (PAS de flèche retour dans l'UI)
        _sess.minimizeAndHideUI(context);
        return false;
      },
      child: Scaffold(
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

            // Badge de statut
            if (_start != null && _statusHint != null)
              Positioned(
                left: 16, right: 16, bottom: 140,
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
          ]),
        ),
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
              Text(_start == null ? 'Calling…'.tr : (_isGroup ? 'In group call…'.tr : 'In call…'.tr),
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
        _endSignaled = true;
      }
    }

    _sess.clearSession(disposeRtc: true); // 👈
    _safePop();
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
