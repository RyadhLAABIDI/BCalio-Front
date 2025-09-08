import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'socket_service.dart';

class ChatPaneController extends GetxController {
  static ChatPaneController get to => Get.find();

  final messages = <Map<String, dynamic>>[].obs;

  // ✅ anti-doublons par id de message
  final Set<String> _seenIds = <String>{};

  void addMessage(Map<String, dynamic> msg) {
    final id = msg['id']?.toString();
    if (id != null && id.isNotEmpty) {
      if (_seenIds.contains(id)) return;
      _seenIds.add(id);
    }
    messages.add(msg);
  }

  void setHistory(List hist) {
    messages.clear();
    _seenIds.clear();
    for (final raw in hist) {
      final m = Map<String, dynamic>.from(raw as Map);
      final id = m['id']?.toString();
      if (id != null && id.isNotEmpty) _seenIds.add(id);
      messages.add(m);
    }
  }
}

class ChatPane extends StatefulWidget {
  const ChatPane({super.key});
  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final _inputCtrl = TextEditingController();
  final Color neonBlue = const Color(0xFF00CFFF);

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ChatPaneController>()) {
      Get.put(ChatPaneController());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Expanded(
            child: Obx(() {
              final msgs = ChatPaneController.to.messages;
              return ListView.builder(
                itemCount: msgs.length,
                itemBuilder: (_, i) {
                  final m = msgs[i];
                  final mine = m['mine'] ?? false;
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: mine
                              ? [Colors.black, neonBlue.withOpacity(0.7)]
                              : [Colors.grey.shade800, Colors.grey.shade600],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${m['name']}: ${m['msg']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: neonBlue,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  decoration: InputDecoration(
                    hintText: 'Message…'.tr,
                    hintStyle: TextStyle(
                      color: neonBlue.withOpacity(0.6),
                      fontFamily: 'Orbitron',
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: neonBlue.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: neonBlue),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: TextStyle(
                    color: neonBlue,
                    fontFamily: 'Orbitron',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _send,
                icon: Icon(Icons.send, size: 20, color: neonBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ⬇️ Fallback HTTP seulement si PAS encore "entered"
  void _send() {
    final txt = _inputCtrl.text.trim();
    if (txt.isEmpty) return;

    final socketService = Get.find<SocketService>();
    final roomId      = socketService.currentRoomId;
    final displayName = socketService.currentDisplayName;

    if (roomId.isEmpty || displayName.isEmpty) {
      Get.snackbar('Erreur', 'Room ou user manquants.',
        backgroundColor: Colors.red, colorText: Colors.white, snackPosition: SnackPosition.BOTTOM);
      return;
    }

    if (!socketService.entered) {
      socketService.sendMessageHttp(roomId, displayName, txt);
    } else {
      socketService.sendMessage(roomId, displayName, txt);
    }

    _inputCtrl.clear();
  }
}
