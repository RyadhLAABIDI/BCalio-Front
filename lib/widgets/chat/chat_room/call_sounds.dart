import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

/// Utilitaire global pour toutes les sonneries d’appel.
///
/// ➊  Ring-back (appelant)       → assets/ringback.mp3 (boucle)
/// ➋  Occupé (busy)              → assets/busy_tone.mp3 (1x)
/// ➌  Fin d’appel (bip court)    → assets/call_end.mp3 (1x)
/// ➍  Sonnerie entrante (dest.)  → Android natif via MethodChannel, sinon fallback MP3
class CallSounds {
  CallSounds._();

  /* players */
  static final _ringPlayer   = AudioPlayer();
  static final _busyPlayer   = AudioPlayer();
  static final _endPlayer    = AudioPlayer();
  static final _incomingPlayer = AudioPlayer();

  static bool _ringOn = false;
  static bool _incomingOn = false;

  /* ======================= RING-BACK (APPELANT) ======================= */
  static Future<void> playRingBack() async {
    if (_ringOn) return;
    _ringOn = true;
    try {
      await _ringPlayer.setAsset('assets/ringback.mp3');
      await _ringPlayer.setLoopMode(LoopMode.one);
      _ringPlayer.play();
    } catch (_) {
      _ringOn = false;
    }
  }

  static Future<void> stopRingBack() async {
    if (!_ringOn) return;
    _ringOn = false;
    try { await _ringPlayer.stop(); } catch (_) {}
  }

  /* ======================= BUSY (refus) ======================= */
  static Future<void> playBusyOnce() async {
    try {
      await _busyPlayer.stop();
      await _busyPlayer.setLoopMode(LoopMode.off);
      await _busyPlayer.setAsset('assets/busy_tone.mp3');
      await _busyPlayer.play();
    } catch (_) {}
  }

  /* ======================= END BEEP (fin / timeout) ======================= */
  static Future<void> playEndBeep() async {
    try {
      await _endPlayer.stop();
      await _endPlayer.setLoopMode(LoopMode.off);
      await _endPlayer.setAsset('assets/call_end.mp3');
      await _endPlayer.play();
    } catch (_) {}
  }

  /* ======================= INCOMING (DESTINATAIRE) ======================= */
  static const _ch = MethodChannel('call_sounds');

  static Future<void> playIncoming() async {
    if (_incomingOn) return;
    _incomingOn = true;

    if (Platform.isAndroid) {
      try {
        await _ch.invokeMethod('playIncoming');
        return;
      } catch (_) {/* fallback */}
    }

    // Fallback: réutilise ringback comme sonnerie, en boucle
    try {
      await _incomingPlayer.setAsset('assets/ringback.mp3');
      await _incomingPlayer.setLoopMode(LoopMode.one);
      _incomingPlayer.play();
    } catch (_) {}
  }

  static Future<void> stopIncoming() async {
    if (!_incomingOn) return;
    _incomingOn = false;

    if (Platform.isAndroid) {
      try { await _ch.invokeMethod('stopIncoming'); } catch (_) {}
    }

    try { await _incomingPlayer.stop(); } catch (_) {}
  }
}
