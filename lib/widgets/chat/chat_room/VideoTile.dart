import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoTile extends StatefulWidget {
  final String id;
  final String name;
  final MediaStream? stream;
  final bool isSelf;
  final bool fullScreen; // 👈 nouveau

  const VideoTile({
    super.key,
    required this.id,
    required this.name,
    required this.stream,
    this.isSelf = false,
    this.fullScreen = false,
  });

  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> {
  final _renderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _initRenderer();
  }

  Future<void> _initRenderer() async {
    await _renderer.initialize();
    if (widget.stream != null) _renderer.srcObject = widget.stream;
    setState(() {});
  }

  @override
  void didUpdateWidget(VideoTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stream != oldWidget.stream && widget.stream != null) {
      _renderer.srcObject = widget.stream;
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _renderer.textureId != null;

    // ➜ mode plein écran: on remplit vraiment tout
    if (widget.fullScreen) {
      return Stack(
        fit: StackFit.expand,
        children: [
          hasVideo
              ? RTCVideoView(
                  _renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: widget.isSelf,
                )
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          Positioned(
            left: 8,
            bottom: 8,
            child: _nameChip(),
          ),
        ],
      );
    }

    // ➜ mode "tuile" (grille)
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasVideo)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: RTCVideoView(
                _renderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                mirror: widget.isSelf,
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          Positioned(
            left: 4,
            bottom: 4,
            child: _nameChip(fontSize: 12, padH: 6, padV: 2),
          ),
        ],
      ),
    );
  }

  Widget _nameChip({double fontSize = 14, double padH = 8, double padV = 4}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        widget.name,
        style: TextStyle(color: Colors.white, fontSize: fontSize),
      ),
    );
  }
}
