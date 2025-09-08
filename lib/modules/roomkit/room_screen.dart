import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'webrtc_controller.dart';
import 'socket_service.dart';
import 'chat_pane.dart';
import 'video_tile.dart';
import 'bcallio_orbit_background.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final String displayName;

  const RoomScreen({
    super.key,
    required this.roomId,
    required this.displayName,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final WebRTCController _rtc;
  late final SocketService _sock;

  // Couleurs
  final Color neonBlue = const Color(0xFF00CFFF);
  final Color warmRoomTitle = const Color(0xFFC46535);

  bool? _isOwner;

  @override
  void initState() {
    super.initState();

    if (!Get.isRegistered<ChatPaneController>()) {
      Get.put(ChatPaneController());
    }

    _rtc = WebRTCController(
      roomId: widget.roomId,
      displayName: widget.displayName,
    )..onInit();

    _sock = SocketService();
    Get.put<SocketService>(_sock);

    // ✅ Attacher le socket AVANT de se connecter (handlers SDP prêts)
    _rtc.attachSocket(_sock);

    _sock.connectAndJoin(
      widget.roomId,
      widget.displayName,
      onApproved: () {
        _isOwner ??= false;
        if (Get.isDialogOpen == true && Get.context != null) {
          Navigator.of(Get.context!, rootNavigator: true).pop();
        }
      },
      onPendingRequest: (id, name) {
        setState(() => _isOwner = true);
        _showPendingDialog(id, name);
      },
      onExistingUsers: (users) {
        if (users.isEmpty) setState(() => _isOwner = true);
        for (final u in users) {
          if (u['id'] != _sock.id) {        // ❌ ne pas s’ajouter soi-même
            _rtc.addPeer(u['id'], u['name']);
          }
        }
      },
      onUserConnected: (id, name) {
        if (id != _sock.id) {               // ❌ ne pas créer un peer vers soi-même
          _rtc.addPeer(id, name);
        }
      },
      onUserDisconnected: _rtc.removePeer,

      // ✅ Historique : calcule "mine" avant d’injecter
      onChatHistory: (hist) {
        final myId   = _sock.id;
        final myName = widget.displayName;
        final mapped = hist.map((raw) {
          final p = Map<String, dynamic>.from(raw);
          final from = p['from']?.toString();
          final name = p['name']?.toString();
          p['mine'] = (from != null && from == myId) || (name != null && name == myName);
          return p;
        }).toList();
        ChatPaneController.to.setHistory(mapped);
      },

      // ✅ Messages temps réel : calcule "mine" + dédup par id dans le controller
      onChat: (payload) {
        final p = Map<String, dynamic>.from(payload);
        final from = p['from']?.toString();
        final name = p['name']?.toString();
        p['mine'] = (from != null && from == _sock.id) || (name != null && name == widget.displayName);
        ChatPaneController.to.addMessage(p);
      },
    );
  }

  void _showPendingDialog(String id, String name) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Demande de connexion',
          style: TextStyle(color: neonBlue, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '$name souhaite rejoindre la room.',
          style: TextStyle(color: neonBlue.withOpacity(0.9)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _sock.approveUser(widget.roomId, id, false);
              if (Get.context != null) {
                Navigator.of(Get.context!, rootNavigator: true).pop();
              }
            },
            child: Text('Refuser', style: TextStyle(color: neonBlue)),
          ),
          ElevatedButton(
            onPressed: () {
              _sock.approveUser(widget.roomId, id, true);
              if (Get.context != null) {
                Navigator.of(Get.context!, rootNavigator: true).pop();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: neonBlue,
              foregroundColor: Colors.black,
            ),
            child: const Text('Accepter', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  @override
  void dispose() {
    _rtc.leave();
    _sock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;

    final translucentTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      dialogBackgroundColor: Colors.transparent,
      cardColor: Colors.black.withOpacity(0.12),
      colorScheme: Theme.of(context).colorScheme.copyWith(
        surface: Colors.transparent,
        surfaceTint: Colors.transparent,
        surfaceVariant: Colors.transparent,
      ),
    );

    return Theme(
      data: translucentTheme,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const Positioned.fill(
              child: IgnorePointer(child: CelestialOrbitsBackground()),
            ),
            Positioned.fill(child: Container(color: Colors.black.withOpacity(0.45))),
            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Material(
                      type: MaterialType.transparency,
                      child: Obx(() => GridView.builder(
                            padding: const EdgeInsets.all(8),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8,
                            ),
                            itemCount: _rtc.participants.length,
                            itemBuilder: (_, i) {
                              final p = _rtc.participants[i];
                              return Material(
                                type: MaterialType.transparency,
                                child: VideoTile(
                                  id: p.id,
                                  name: p.displayName,
                                  stream: p.stream,
                                  isSelf: p.id == _rtc.selfId || p.id == 'self',
                                ),
                              );
                            },
                          )),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedPadding(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(bottom: kb),
                    child: const SizedBox(
                      height: 300,
                      child: Material(
                        type: MaterialType.transparency,
                        child: ChatPane(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CelestialOrbitsBackground(overlayMode: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: neonBlue.withOpacity(0.3), width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            'Room ${widget.roomId}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: warmRoomTitle,
              fontSize: 18,
              letterSpacing: 1.2,
            ),
          ),
          if (_isOwner == true)
            const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.star, size: 16, color: Colors.yellow),
            ),
          const Spacer(),
          Obx(() => IconButton(
                onPressed: _rtc.toggleMic,
                icon: Icon(
                  _rtc.micOn.value ? Icons.mic : Icons.mic_off,
                  color: _rtc.micOn.value ? Colors.green : Colors.red,
                  size: 28,
                ),
              )),
          Obx(() => IconButton(
                onPressed: _rtc.toggleCam,
                icon: Icon(
                  _rtc.camOn.value ? Icons.videocam : Icons.videocam_off,
                  color: _rtc.camOn.value ? Colors.green : Colors.red,
                  size: 28,
                ),
              )),
          IconButton(
            onPressed: () {
              _rtc.leave();
              _sock.dispose();
              Get.back();
            },
            icon: const Icon(Icons.exit_to_app, color: Colors.red, size: 28),
            tooltip: 'Quitter la room',
          ),
        ],
      ),
    );
  }
}
