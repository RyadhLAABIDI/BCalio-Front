import 'package:flutter_webrtc/flutter_webrtc.dart';

class Participant {
  final String id;
  final String displayName;
  MediaStream? stream;

  Participant({required this.id, required this.displayName, this.stream});
}
