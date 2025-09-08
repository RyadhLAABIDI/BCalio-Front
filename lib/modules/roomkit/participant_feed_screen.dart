import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'socket_service.dart';

class ParticipantFeedScreen extends StatefulWidget {
  final String roomId;
  final String participantId;

  const ParticipantFeedScreen({
    super.key,
    required this.roomId,
    required this.participantId,
  });

  @override
  State<ParticipantFeedScreen> createState() => _ParticipantFeedScreenState();
}

class _ParticipantFeedScreenState extends State<ParticipantFeedScreen> {
  late final SocketService _sock;
  RTCPeerConnection? _pc;
  final _renderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initRendererAndSocket();
  }

  Future<void> _initRendererAndSocket() async {
    await _renderer.initialize();

    _sock = SocketService();

    _sock.connectAndJoin(
      widget.roomId,
      'FeedViewer',
      onApproved: () => _sock.enterRoom(widget.roomId, 'FeedViewer'),
      onExistingUsers: (users) {
        if (users.any((u) => u['id'] == widget.participantId)) {
          _setupPeer();
        }
      },
    );

    _sock.onOffer = _handleOffer;
    _sock.onAnswer = _handleAnswer;
    _sock.onIce = _handleIce;
  }

  Future<void> _setupPeer() async {
    if (_pc != null) return;

    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    });

    _pc!.onIceCandidate = (c) {
      if (c != null) {
        _sock.emitIce(widget.participantId, c.toMap());
      }
    };

    _pc!.onTrack = (event) {
      if (event.track.kind == 'video') {
        _renderer.srcObject = event.streams[0];
        setState(() {});
      }
    };

    final offer = await _pc!.createOffer();
    await _pc!.setLocalDescription(offer);
    _sock.emitOffer(widget.participantId, offer.toMap());
  }

  Future<void> _handleOffer(String from, Map sdp) async {
    if (from != widget.participantId) return;
    await _setupPeer();
    await _pc!.setRemoteDescription(
      RTCSessionDescription(sdp['sdp'], sdp['type']),
    );
    final answer = await _pc!.createAnswer();
    await _pc!.setLocalDescription(answer);
    _sock.emitAnswer(from, answer.toMap());
  }

  Future<void> _handleAnswer(String from, Map sdp) async {
    if (from != widget.participantId) return;
    await _pc?.setRemoteDescription(
      RTCSessionDescription(sdp['sdp'], sdp['type']),
    );
  }

  Future<void> _handleIce(String from, Map ice) async {
    if (from != widget.participantId) return;
    await _pc?.addCandidate(
      RTCIceCandidate(ice['candidate'], ice['sdpMid'], ice['sdpMLineIndex']),
    );
  }

  @override
  void dispose() {
    _renderer.dispose();
    _pc?.close();
    _sock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Feed ${widget.participantId}')),
      body: Center(
        child: _renderer.textureId == null
            ? const CircularProgressIndicator()
            : RTCVideoView(_renderer, mirror: true),
      ),
    );
  }
}
