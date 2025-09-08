import 'dart:async';
import 'package:get/get.dart';
import '../services/webrtccontroller.dart';
import 'package:flutter/material.dart';

enum CallKind { audio, video }

/// Petite fabrique fournie depuis main.dart pour reconstruire l’UI d’appel
class CallUiFactory {
  static Widget Function()? _audioBuilder;
  static Widget Function()? _videoBuilder;

  static void provide({
    required Widget Function() audio,
    required Widget Function() video,
  }) {
    _audioBuilder = audio;
    _videoBuilder = video;
  }

  static Widget? build(CallKind kind) {
    if (kind == CallKind.audio) return _audioBuilder?.call();
    return _videoBuilder?.call();
  }
}

/// Contrôleur global du cycle de vie d’un appel (bandeau vert + restauration)
class OngoingCallController extends GetxController {
  static final OngoingCallController I =
      Get.put(OngoingCallController(), permanent: true);

  // État de session courant
  final callId     = RxnString();
  final isGroup    = false.obs;
  final isCaller   = false.obs;
  final kind       = CallKind.audio.obs;

  final peerId     = RxnString();
  final peerName   = RxnString();
  final peerAvatar = RxnString();

  final startedAt  = Rxn<DateTime>();

  // UI globale
  final inCall     = false.obs;
  final minimized  = false.obs;

  // Référence WebRTC (à ne pas détruire sur simple minimize)
  WebRTCController? rtc;

  // Chrono global (utilisé par le bandeau et les écrans restaurés)
  final elapsedText = '00:00'.obs;
  Timer? _ticker;

  void _tick() {
    final s = startedAt.value;
    if (s == null) { elapsedText.value = '00:00'; return; }
    final d = DateTime.now().difference(s);
    final m = d.inMinutes.toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    elapsedText.value = '$m:$ss';
  }

  /// Démarre (ou attache) une session globale. Ne détruit rien si déjà présent.
  void startSession({
    required String callId_,
    required CallKind kind_,
    required bool isGroup_,
    required String? peerId_,
    required String peerName_,
    required String? peerAvatar_,
    required WebRTCController rtcController,
    required DateTime? startedAt_, // null avant accept
    bool isCaller_ = false,
  }) {
    callId.value     = callId_;
    isGroup.value    = isGroup_;
    isCaller.value   = isCaller_;
    kind.value       = kind_;
    peerId.value     = peerId_;
    peerName.value   = peerName_;
    peerAvatar.value = peerAvatar_;
    rtc              = rtcController;

    inCall.value     = true;
    minimized.value  = false;

    startedAt.value  = startedAt_;   // peut rester null jusqu’à accept
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _tick();
  }

  /// À appeler quand le serveur émet "call-accepted" (début chrono global)
  void markAcceptedNow() {
    if (startedAt.value == null) {
      startedAt.value = DateTime.now();
      _tick();
    }
  }

  /// Minimise l’UI d’appel (le bandeau vert s’affiche)
  void minimize() {
    if (!inCall.value) return;
    minimized.value = true;
  }

  /// Restaure l’UI au tap du bandeau
  Future<void> restoreUI() async {
    if (!inCall.value || !minimized.value) return;
    final page = CallUiFactory.build(kind.value);
    if (page == null) return;
    minimized.value = false;
    // Utilise Get pour remonter l’écran au-dessus de tout
    await Get.to(() => page, fullscreenDialog: true, preventDuplicates: false);
  }

  /// Annule une session non acceptée (timers + reset)
  Future<void> cancelBeforeAccepted() async {
    _ticker?.cancel();
    _ticker = null;
    startedAt.value = null;
    elapsedText.value = '00:00';
    minimized.value = false;
    inCall.value = false;
    // Pas de rtc.leave() ici: pas de flux engagé avant accept.
  }

  /// Termine la session (appel raccroché)
  Future<void> endSession() async {
    _ticker?.cancel();
    _ticker = null;
    elapsedText.value = '00:00';
    minimized.value = false;
    inCall.value = false;

    try { rtc?.leave(); } catch (_) {}
    rtc = null;

    // purge infos
    callId.value = null;
    peerId.value = null;
    peerName.value = null;
    peerAvatar.value = null;
    startedAt.value = null;
  }
}
