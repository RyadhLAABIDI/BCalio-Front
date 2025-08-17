import 'package:bcalio/models/call_log_model.dart';
import 'package:bcalio/controllers/user_controller.dart';
import 'package:bcalio/widgets/chat/chat_room/audio_call_screen.dart';
import 'package:bcalio/widgets/chat/chat_room/video_call_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Point central pour démarrer un appel depuis l’UI (journal, profil, etc.)
class CallLauncher {
  CallLauncher._();

  /// depuis un CallLog (choix audio/vidéo via [video])
  static Future<void> fromLog(CallLog log, {required bool video}) async {
    await startCall(
      peerId: log.peerId,
      peerName: log.peerName,
      avatarUrl: log.peerAvatar,
      video: video,
    );
  }

  /// générique
  static Future<void> startCall({
    required String peerId,
    required String peerName,
    String? avatarUrl,
    required bool video,
  }) async {
    final me = Get.find<UserController>();
    final selfId   = me.userId;
    final isVideo  = video;

    final page = isVideo
        ? VideoCallScreen(
            name:        peerName,
            avatarUrl:   avatarUrl,
            phoneNumber: '',
            recipientID: peerId,
            userId:      selfId,
            isCaller:    true,
            existingCallId: null,
          )
        : AudioCallScreen(
            name:        peerName,
            avatarUrl:   avatarUrl,
            phoneNumber: '',
            recipientID: peerId,
            userId:      selfId,
            isCaller:    true,
            existingCallId: null,
          );

    // petite anim d’ouverture (fade-in)
    await Get.to(() => page,
        transition: Transition.fadeIn, duration: const Duration(milliseconds: 180));
  }
}
