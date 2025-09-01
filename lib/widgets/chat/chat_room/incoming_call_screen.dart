import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:bcalio/widgets/chat/chat_room/call_sounds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:flutter/services.dart';

import '../../../controllers/user_controller.dart';
import 'audio_call_screen.dart';
import 'video_call_screen.dart';

/* ---- Journal d’appel ---- */
import '../../../controllers/call_log_controller.dart';
import '../../../models/call_log_model.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerId;
  final String callId;
  final String callType;      // 'audio' | 'video'
  final String? avatarUrl;
  final String recipientID;   // moi

  final bool isGroup;
  final List<String> members; // sans moi

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerId,
    required this.callId,
    required this.callType,
    required this.avatarUrl,
    required this.recipientID,
    this.isGroup = false,
    this.members = const [],
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  static const _platform = MethodChannel('incoming_calls');
  static const Duration _uiRingTimeout = Duration(seconds: 32);

  Timer? _autoDismiss;
  bool   _closed = false;

  // --- Animations ---
  // 1) Breathing pour icônes (corrigée via Tween 0.96 -> 1.06)
  late final AnimationController _pulseCtl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);
  late final Animation<double> _pulse =
      Tween<double>(begin: 0.96, end: 1.06).animate(
        CurvedAnimation(parent: _pulseCtl, curve: Curves.easeInOut),
      );

  // 2) Rotation anneau néon (boucle lente)
  late final AnimationController _ringCtl =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();

  // 3) Compte à rebours (progress ring) 0 -> 1 sur la durée du ring UI
  late final AnimationController _timeoutCtl =
      AnimationController(vsync: this, duration: _uiRingTimeout)
        ..forward();

  // 4) Shimmer doux sur la carte glass des boutons
  late final AnimationController _shimmerCtl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
        ..repeat();

  // -------- helper: fermeture sûre (évite le bug GetX snackbar) --------
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

    CallSounds.playIncoming();

    _autoDismiss?.cancel();
    _autoDismiss = Timer(_uiRingTimeout, () async {
      if (!mounted || _closed) return;
      try {
        await _platform.invokeMethod('ui_timeout', {'callId': widget.callId});
      } catch (_) {}
      await _log(CallStatus.missed);
      _close();
    });

    final sock = Get.find<UserController>().socketService;
    sock
      ..onCallCancelled = () { _onRemoteEnd(CallStatus.cancelled); }
      ..onCallEnded     = () { _onRemoteEnd(CallStatus.missed); }
      ..onCallTimeout   = () { _onRemoteEnd(CallStatus.missed); };
  }

  void _onRemoteEnd(CallStatus status) async {
    if (_closed) return;
    await _log(status);
    _close();
  }

  void _cancelLocalTimer() {
    _autoDismiss?.cancel();
    _autoDismiss = null;
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    _cancelLocalTimer();
    CallSounds.stopIncoming();
    if (mounted) _safePop(); // ← au lieu de Get.back()
  }

  @override
  void dispose() {
    _cancelLocalTimer();
    CallSounds.stopIncoming();
    _pulseCtl.dispose();
    _ringCtl.dispose();
    _timeoutCtl.dispose();
    _shimmerCtl.dispose();
    super.dispose();
  }

  Future<void> _log(CallStatus status) async {
    try {
      final ctrl = Get.find<CallLogController>();
      await ctrl.upsert(CallLog(
        callId: widget.callId,
        peerId: widget.callerId,
        peerName: widget.callerName,
        peerAvatar: widget.avatarUrl,
        direction: CallDirection.incoming,
        type: widget.callType == 'video' ? CallType.video : CallType.audio,
        status: status,
        startedAt: DateTime.now(),
        endedAt: null,
        durationSeconds: 0,
      ));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.callType == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // --- fond ---
          Positioned.fill(
            child: widget.avatarUrl != null
                ? Image.network(widget.avatarUrl!, fit: BoxFit.cover)
                : Container(color: Colors.black),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(.6))),

          // --- avatar + titres + anneaux premium ---
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 110),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Anneaux + avatar
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Anneau néon (rotation continue)
                        AnimatedBuilder(
                          animation: _ringCtl,
                          builder: (_, __) => CustomPaint(
                            size: const Size(150, 150),
                            painter: _NeonSweepPainter(angle: _ringCtl.value * 2 * math.pi),
                          ),
                        ),
                        // Progress (compte à rebours)
                        AnimatedBuilder(
                          animation: _timeoutCtl,
                          builder: (_, __) => CustomPaint(
                            size: const Size(150, 150),
                            painter: _ProgressRingPainter(progress: _timeoutCtl.value),
                          ),
                        ),
                        // Avatar (Hero optionnel – sans impact si pas de pair)
                        Hero(
                          tag: 'callAvatar_${widget.callId}',
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white24,
                            backgroundImage: (widget.avatarUrl ?? '').isNotEmpty
                                ? NetworkImage(widget.avatarUrl!)
                                : null,
                            child: (widget.avatarUrl ?? '').isEmpty
                                ? const Icon(Iconsax.user, color: Colors.white, size: 48)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    widget.callerName,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.isGroup
                        ? (isVideo ? 'Group video call'.tr : 'Group audio call'.tr)
                        : (isVideo ? 'Video call'.tr : 'Audio call'.tr),
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

          // ====== Zone boutons avec effet glass + blur + shimmer ======
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Stack(
                    children: [
                      // Carte “glass”
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.white.withOpacity(0.08),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.10),
                              Colors.white.withOpacity(0.04),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(.25),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // -------- accepter --------
                            SlideAction(
                              height: 64,
                              elevation: 0,
                              innerColor : Colors.green,
                              outerColor : Colors.green.withOpacity(.22),
                              borderRadius: 40,
                              text: 'swipe_to_answer'.tr,
                              textStyle: TextStyle(
                                color: Colors.white.withOpacity(.95),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .2,
                              ),
                              sliderButtonIcon: ScaleTransition(
                                scale: _pulse,
                                child: const Icon(Icons.call, color: Colors.white, size: 28),
                              ),
                              onSubmit: () async {
                                HapticFeedback.mediumImpact();
                                _cancelLocalTimer();
                                CallSounds.stopIncoming();

                                try {
                                  await _platform.invokeMethod('ui_accept', {'callId': widget.callId});
                                } catch (_) {}

                                Get.off(() => isVideo
                                    ? VideoCallScreen(
                                        name:          widget.callerName,
                                        avatarUrl:     widget.avatarUrl,
                                        phoneNumber:   '',
                                        recipientID:   widget.isGroup ? '' : widget.callerId,
                                        userId:        widget.recipientID,
                                        isCaller:      false,
                                        existingCallId: widget.callId,
                                        isGroup:       widget.isGroup,
                                        memberIds:     widget.members,
                                        shouldSendLocalAccept: true,
                                      )
                                    : AudioCallScreen(
                                        name:          widget.callerName,
                                        avatarUrl:     widget.avatarUrl,
                                        phoneNumber:   '',
                                        recipientID:   widget.isGroup ? '' : widget.callerId,
                                        userId:        widget.recipientID,
                                        isCaller:      false,
                                        existingCallId: widget.callId,
                                        isGroup:       widget.isGroup,
                                        memberIds:     widget.members,
                                        shouldSendLocalAccept: true,
                                      ));
                              },
                            ),
                            const SizedBox(height: 16),

                            // -------- refuser --------
                            SlideAction(
                              height: 64,
                              elevation: 0,
                              innerColor : Colors.red,
                              outerColor : Colors.red.withOpacity(.22),
                              borderRadius: 40,
                              text: 'swipe_to_decline'.tr,
                              textStyle: TextStyle(
                                color: Colors.white.withOpacity(.95),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: .2,
                              ),
                              sliderButtonIcon: ScaleTransition(
                                scale: _pulse,
                                child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                              ),
                              onSubmit: () async {
                                HapticFeedback.mediumImpact();
                                _cancelLocalTimer();
                                CallSounds.stopIncoming();
                                await _log(CallStatus.rejected);

                                try {
                                  await _platform.invokeMethod('ui_reject', {
                                    'callId'    : widget.callId,
                                    'callerId'  : widget.callerId,
                                    'callerName': widget.callerName,
                                    'avatarUrl' : widget.avatarUrl ?? '',
                                  });
                                } catch (_) {}

                                final sock = Get.find<UserController>().socketService;
                                sock.rejectCall(widget.callId, widget.recipientID);
                                _close();
                              },
                            ),
                          ],
                        ),
                      ),

                      // Shimmer doux qui traverse la carte
                      IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _shimmerCtl,
                          builder: (_, __) {
                            // -1 → +1 mappé en offset horizontal
                            final dx = (_shimmerCtl.value * 2 - 1) * 260;
                            return Opacity(
                              opacity: 0.14,
                              child: Transform.translate(
                                offset: Offset(dx, 0),
                                child: Container(
                                  height: 140,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white,
                                        Colors.transparent,
                                      ],
                                      stops: [0.35, 0.5, 0.65],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* =================== Painters des anneaux =================== */

class _ProgressRingPainter extends CustomPainter {
  final double progress; // 0..1

  _ProgressRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 6.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) / 2) - stroke;

    final bg = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    // fond
    canvas.drawCircle(center, radius, bg);

    // arc progress
    final sweep = (progress.clamp(0.0, 1.0)) * 2 * math.pi;
    if (sweep <= 0) return;

    final fg = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: 3 * math.pi / 2,
        colors: const [
          Color(0xFF7AE9FF), // cyan
          Color(0xFF8F7CFF), // violet clair
          Color(0xFF7AE9FF),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke + 0.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.progress != progress;
}

class _NeonSweepPainter extends CustomPainter {
  final double angle; // rotation en radians

  _NeonSweepPainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 8.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (math.min(size.width, size.height) / 2) - stroke;

    // petit arc lumineux qui tourne
    final glow = Paint()
      ..color = const Color(0xFF00E1FF).withOpacity(0.70)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // arc court (environ 40°)
    const arcLen = math.pi / 4.5;
    final start = angle - arcLen / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      arcLen,
      false,
      glow,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonSweepPainter old) =>
      old.angle != angle;
}
