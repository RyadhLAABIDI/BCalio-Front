import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  late Box _messageBox;

  Future<void> init() async {
    await Hive.initFlutter();
    _messageBox = await Hive.openBox('messages');
  }

  void saveMessage(String conversationId, Map<String, dynamic> message) {
    final messages = _messageBox.get(conversationId, defaultValue: []) as List;
    messages.add(message);
    _messageBox.put(conversationId, messages);
  }

  List<Map<String, dynamic>> getMessages(String conversationId) {
    return (_messageBox.get(conversationId, defaultValue: []) as List)
        .cast<Map<String, dynamic>>();
  }

  void saveAllMessages(
      String conversationId, List<Map<String, dynamic>> messages) {
    _messageBox.put(conversationId, messages);
  }
}
