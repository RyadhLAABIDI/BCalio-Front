import 'dart:async';

import 'package:bcalio/widgets/chat/chat_room/VideoTile.dart';
import 'package:bcalio/widgets/chat/chat_room/call_sounds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:collection/collection.dart'; // pour firstWhereOrNull

import '../../../controllers/user_controller.dart';
import '../../../services/webrtccontroller.dart';

/* ---- Journal d’appel ---- */
import '../../../controllers/call_log_controller.dart';
import '../../../models/call_log_model.dart';

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

  // 👇 flag pour autoAccept
  final bool shouldSendLocalAccept;

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
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with SingleTickerProviderStateMixin {

  static const _platform = MethodChannel('incoming_calls'); // Android notifications

  bool _micOn     = true,
       _camOn     = true,
       _speakerOn = true, // haut-parleur activé par défaut en vidéo
       _show      = true,
       _sent      = false; // pour l’appelant

  bool _acceptSent = false; // destinataire (local accept)

  // ⬇️ Anti-doublons / contrôle de fin locale
  bool _handledTerminal = false;
  bool _locallyEnded    = false;
  bool _endSignaled     = false;

  // ⬇️ Marquage natif
  bool _nativeAcceptMarked = false;
  bool _nativeRejectMarked = false;

  late final AnimationController _anim;
  late final Animation<double>   _scale;

  late final WebRTCController _rtc;

  String?   _callId;
  DateTime? _start;          // null = sonnerie
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
      baseUrl  : 'https://backendcall.b-callio.com',
      callId   : '${me.userId}_${_isGroup ? 'group' : widget.recipientID}',
      selfName : me.userName,
      withVideo: true,
    )..onInit();
    _rtc.attachSocket(me.socketService);

    // Toasts UI (appelant en groupe)
    if (_isGroup && widget.isCaller) {
      _rtc.onUiParticipantJoined  = (uid, name) =>
          _toast('${name.isNotEmpty ? name : uid} ${'a rejoint l’appel'.tr}');
      _rtc.onUiParticipantTimeout = (_) {};
    }

    final sock = me.socketService;

    // === 1) POSER LES LISTENERS AVANT D'ÉMETTRE L’APPEL ===
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
        });
      }

      // Marque "accepted" côté Android (A et B)
      if (!_nativeAcceptMarked) {
        _nativeAcceptMarked = true;
        final idToMark = (cid.isNotEmpty)
            ? cid
            : (widget.existingCallId ?? '${widget.userId}_${_isGroup ? "group" : widget.recipientID}');
        try { _platform.invokeMethod('ui_accept', {'callId': idToMark}); } catch (_) {}
      }

      // 1-to-1 : relier les pairs (A en initiator, B en non-initiator)
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

      // Marque "rejected" pour éviter les "missed" parasites
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
    };

    sock.onCallEnded = () {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      _showBanner('Appel terminé'.tr, Colors.white70);
      _finishAfterBeep(() => CallSounds.playEndBeep());
      _log(CallStatus.ended, endedAt: DateTime.now());
    };

    sock.onCallCancelled = () {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      _safePop();
      _log(CallStatus.cancelled);
    };

    sock.onCallError = (_) {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      _safePop();
    };

    sock.onCallTimeout = () {
      if (_handledTerminal) return;
      _handledTerminal = true;
      _fallbackTimeout?.cancel();
      CallSounds.stopRingBack();
      _showBanner('Ne répond pas'.tr, Colors.orange);
      _finishAfterBeep(() => CallSounds.playEndBeep());
      _log(CallStatus.timeout);
    };

    // === 2) DESTINATAIRE : préconfig (attend l’offer entrant)
    if (!widget.isCaller && widget.existingCallId != null) {
      _callId = widget.existingCallId;
      if (!_isGroup) {
        _rtc.addPeer(widget.recipientID, widget.name, initiator: false);
      }
    }

    // === 3) APPELANT : émettre l’appel APRÈS avoir posé les listeners
    if (widget.isCaller && !_sent) {
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

        // Annuler côté serveur pour fermer l’écran chez B
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

    // === 4) destinataire auto-accept (depuis notif plein écran)
    if (!widget.isCaller && widget.shouldSendLocalAccept && !_acceptSent) {
      _acceptSent = true;
      final idToAccept = widget.existingCallId ?? '${widget.userId}_${_isGroup ? "group" : widget.recipientID}';

      // Marque "accepted" immédiatement côté Android
      try { _platform.invokeMethod('ui_accept', {'callId': idToAccept}); } catch (_) {}

      sock.acceptCall(idToAccept, widget.userId);
    }

    // Haut-parleur selon l’état initial
    rtc.Helper.setSpeakerphoneOn(_speakerOn);

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

  /* ───────────── pop sûr (évite le crash GetX/snackbar) ───────────── */
  void _safePop() {
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) {
      nav.pop();
    }
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
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggle,
        child: Stack(children: [

          /* flux vidéo */
          Positioned.fill(
            child: Obx(() {
              final others = _rtc.participants.where((p) => p.id != 'self').toList();

              // 1-to-1 : plein écran
              if (!_isGroup) {
                final r = others.isNotEmpty ? others.first : null;
                return VideoTile(
                  id: r?.id ?? widget.recipientID,
                  name: r?.displayName ?? widget.name,
                  stream: r?.stream,
                  isSelf: false,
                );
              }

              // Groupe : grille
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
              // TODO : switch caméra (front/back) si besoin
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

    // marque la fin locale et bloque les prochains events terminaux
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
        _endSignaled = true; // évite second endCall en dispose
      }
    }
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
