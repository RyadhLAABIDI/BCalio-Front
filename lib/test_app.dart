// rtc_service.dart
import 'package:flutter_webrtc/flutter_webrtc.dart';

class RTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final Map<String, dynamic> config = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'}
    ]
  };

  Future<MediaStream> getUserMedia() async {
    final stream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': true,
    });
    _localStream = stream;
    return stream;
  }

  Future<void> initPeerConnection() async {
    _peerConnection = await createPeerConnection(config);
    _peerConnection?.onIceCandidate = (candidate) {
      // Send candidate via Pusher
    };
    _peerConnection?.onTrack = (event) {
      _remoteStream = event.streams.first;
    };

    _localStream?.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });
  }

  RTCPeerConnection? get peer => _peerConnection;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  void dispose() {
    _peerConnection?.close();
    _localStream?.dispose();
    _remoteStream?.dispose();
  }
}
