import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

/// Un interlocuteur (local ou distant)
class Participant {
  final String id;
  final String displayName;

  /// Flux média reçu
  rtc.MediaStream? stream;

  /// Renderer indispensable pour que l’audio soit effectivement restitué
  final rtc.RTCVideoRenderer renderer = rtc.RTCVideoRenderer();

  Participant({
    required this.id,
    required this.displayName,
    this.stream,
  });
}
