import 'dart:async';

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

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  static const _platform = MethodChannel('incoming_calls');
  static const Duration _uiRingTimeout = Duration(seconds: 32);

  Timer? _autoDismiss;
  bool   _closed = false;

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
    if (mounted) Get.back();
  }

  @override
  void dispose() {
    _cancelLocalTimer();
    CallSounds.stopIncoming();
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
          Positioned.fill(
            child: widget.avatarUrl != null
                ? Image.network(widget.avatarUrl!, fit: BoxFit.cover)
                : Container(color: Colors.black),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(.6))),

          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 110),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.white24,
                    backgroundImage: (widget.avatarUrl ?? '').isNotEmpty
                        ? NetworkImage(widget.avatarUrl!)
                        : null,
                    child: (widget.avatarUrl ?? '').isEmpty
                        ? const Icon(Iconsax.user, color: Colors.white, size: 48)
                        : null,
                  ),
                  const SizedBox(height: 24),
                  Text(widget.callerName,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(
                    widget.isGroup
                        ? (isVideo ? 'Group video call' : 'Group audio call')
                        : (isVideo ? 'Video call' : 'Audio call'),
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // -------- accepter --------
                  SlideAction(
                    height: 64,
                    elevation: 0,
                    innerColor : Colors.green,
                    outerColor : Colors.green.withOpacity(.25),
                    borderRadius: 40,
                    sliderButtonIcon: const Icon(Iconsax.arrow_up, color: Colors.white, size: 28),
                    onSubmit: () async {
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
                  const SizedBox(height: 20),

                  // -------- refuser --------
                  SlideAction(
                    height: 64,
                    elevation: 0,
                    innerColor : Colors.red,
                    outerColor : Colors.red.withOpacity(.25),
                    borderRadius: 40,
                    sliderButtonIcon: const Icon(Iconsax.arrow_up, color: Colors.white, size: 28),
                    onSubmit: () async {
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
          ),
        ],
      ),
    );
  }
}
