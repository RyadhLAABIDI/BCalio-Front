import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '../services/webrtccontroller.dart';
import '../main.dart' show navigatorKey; // pour naviguer proprement
import '../widgets/chat/chat_room/audio_call_screen.dart';
import '../widgets/chat/chat_room/video_call_screen.dart';

/// Contrôle l’état global d’une session d’appel (métadonnées + RTC + chrono)
class CallSessionController extends GetxController {
  // état UI global
  final isOngoing   = false.obs;      // appel en cours (accepté ou en sonnerie)
  final isMinimized = false.obs;      // UI minimisée (barre globale visible)
  final isVideo     = false.obs;

  // méta affichage
  final name      = ''.obs;
  final avatarUrl = ''.obs;

  // chrono
  DateTime? startedAt;                // fixé à l’acceptation
  final elapsed = '00:00'.obs;
  Timer? _ticker;

  // identités
  String meId = '';
  String peerId = '';
  bool   isCaller = false;
  bool   isGroup  = false;
  List<String> memberIds = const [];
  String? callId;                     // id serveur si dispo (existingCallId)

  // RTC partagé
  WebRTCController? rtc;

  /* ===================== BIND MÉTADONNÉES ===================== */
  void bindMeta({
    required String displayName,
    String? avatar,
    required String meId,
    required String peerId,
    required bool caller,
    required bool group,
    required List<String> members,
    String? cid,
  }) {
    name.value = displayName;
    avatarUrl.value = (avatar ?? '').trim();
    this.meId = meId;
    this.peerId = peerId;
    isCaller = caller;
    isGroup  = group;
    memberIds = members;
    callId = cid;
    isOngoing.value = true; // on est dans un écran d’appel
    // le chrono démarrera vraiment au markAcceptedNow()
    _ensureTicker();
  }

  /* ===================== RTC ===================== */
  void attachRtc(WebRTCController c, {required bool video}) {
    rtc = c;
    isVideo.value = video;
  }

  /* ===================== CHRONO ===================== */
  void markAcceptedNow() {
    if (startedAt == null) {
      startedAt = DateTime.now();
      _ensureTicker();
    }
  }

  void _ensureTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (startedAt == null) {
        elapsed.value = '00:00';
        return;
      }
      final d = DateTime.now().difference(startedAt!);
      final m = d.inMinutes.toString().padLeft(2, '0');
      final s = (d.inSeconds % 60).toString().padLeft(2, '0');
      elapsed.value = '$m:$s';
    });
  }

  /* ===================== MINIMIZE / RESTORE ===================== */
  void minimizeAndHideUI(BuildContext context) {
    isMinimized.value = true;
    // on sort de l’UI d’appel mais on garde le RTC (les écrans ne libéreront
    // pas le média quand isMinimized == true)
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  void restoreCallUI() {
    isMinimized.value = false;

    // rouvre l’UI d’appel correspondante (réutilise le même RTC)
    final ctx = navigatorKey.currentState;
    if (ctx == null) return;

    if (isVideo.value) {
      ctx.push(MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          name: name.value,
          avatarUrl: avatarUrl.value.isEmpty ? null : avatarUrl.value,
          phoneNumber: '',
          recipientID: isGroup ? '' : peerId,
          userId: meId,
          isCaller: isCaller,
          existingCallId: callId,
          isGroup: isGroup,
          memberIds: memberIds,
          shouldSendLocalAccept: false,
          isRestored: true, // 👈 IMPORTANT: évite toute ré-émission
        ),
        fullscreenDialog: true,
      ));
    } else {
      ctx.push(MaterialPageRoute(
        builder: (_) => AudioCallScreen(
          name: name.value,
          avatarUrl: avatarUrl.value.isEmpty ? null : avatarUrl.value,
          phoneNumber: '',
          recipientID: isGroup ? '' : peerId,
          userId: meId,
          isCaller: isCaller,
          existingCallId: callId,
          isGroup: isGroup,
          memberIds: memberIds,
          shouldSendLocalAccept: false,
          isRestored: true, // 👈 IMPORTANT: évite toute ré-émission
        ),
        fullscreenDialog: true,
      ));
    }
  }

  /* ===================== FIN / RESET ===================== */
  /// Nettoie la session. Si disposeRtc==true, on libère aussi le média.
  void clearSession({bool disposeRtc = true}) {
    isOngoing.value = false;
    isMinimized.value = false;
    name.value = '';
    avatarUrl.value = '';
    startedAt = null;
    elapsed.value = '00:00';
    callId = null;
    peerId = '';
    meId = '';
    isCaller = false;
    isGroup  = false;
    memberIds = const [];

    if (disposeRtc) {
      try { rtc?.leave(); } catch (_) {}
      rtc = null;
    }

    _ticker?.cancel();
    _ticker = null;
  }
}
