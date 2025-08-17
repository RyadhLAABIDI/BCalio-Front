import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoCallScreen extends StatefulWidget {
  final String currentUserId;
  final String peerUserId;

  const VideoCallScreen({
    Key? key,
    required this.currentUserId,
    required this.peerUserId,
  }) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    initRenderers();
    startCall(); // simulate call setup (signaling logic to be added)
  }

  Future<void> initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> startCall() async {
    // ⚠️ This is a placeholder. You should implement real signaling here using Pusher, Firebase, or Socket.io
    // For now, only local camera is shown
    final mediaStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'},
    });
    _localRenderer.srcObject = mediaStream;
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Appel Vidéo")),
      body: Stack(
        children: [
          RTCVideoView(_remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          Positioned(
            right: 20,
            top: 20,
            width: 120,
            height: 160,
            child: RTCVideoView(_localRenderer, mirror: true),
          ),
          Positioned(
            bottom: 30,
            left: MediaQuery.of(context).size.width / 2 - 30,
            child: FloatingActionButton(
              backgroundColor: Colors.red,
              child: const Icon(Icons.call_end),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
