import 'package:bcalio/widgets/chat/chat_room/call_sounds.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:flutter/services.dart'; // 👈 pour ui_accept / ui_reject

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
  static const _platform = MethodChannel('incoming_calls'); // 👈

  @override
  void initState() {
    super.initState();
    // ▶️ sonnerie d’appel entrant
    CallSounds.playIncoming();

    // auto-fermeture si l’appelant annule / termine / timeout
    final sock = Get.find<UserController>().socketService;
    void _close() {
      CallSounds.stopIncoming();
      if (mounted) Get.back();
    }
    sock
      ..onCallCancelled = () { _log(CallStatus.cancelled); _close(); }
      ..onCallEnded     = () { _log(CallStatus.missed);    _close(); }
      ..onCallTimeout   = () { _log(CallStatus.missed);    _close(); };
  }

  @override
  void dispose() {
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
    final sock    = Get.find<UserController>().socketService;
    final isVideo = widget.callType == 'video';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // fond
          Positioned.fill(
            child: widget.avatarUrl != null
                ? Image.network(widget.avatarUrl!, fit: BoxFit.cover)
                : Container(color: Colors.black),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(.6))),

          // infos
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

          // actions
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
                      CallSounds.stopIncoming();

                      // 👉 annule le timer + la notif “ringing” côté Android
                      try {
                        await _platform.invokeMethod('ui_accept', {'callId': widget.callId});
                      } catch (_) {}

                      // pas de log ici — l’écran d’appel loggue "accepted" sur event
                      sock.acceptCall(widget.callId, widget.recipientID);

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
                      CallSounds.stopIncoming();
                      _log(CallStatus.rejected);

                      // 👉 aligne la notif avec l’action UI ("Appel refusé")
                      try {
                        await _platform.invokeMethod('ui_reject', {
                          'callId'    : widget.callId,
                          'callerId'  : widget.callerId,
                          'callerName': widget.callerName,
                          'avatarUrl' : widget.avatarUrl ?? '',
                        });
                      } catch (_) {}

                      sock.rejectCall(widget.callId, widget.recipientID);
                      Get.back();
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
