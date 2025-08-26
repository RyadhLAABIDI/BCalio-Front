// lib/services/push_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Petit client pour pinger ton call-server et déclencher la notif message.
class PushApiService {
  // ⚠️ même hôte/port que pour /push/register
  static const String _base = 'https://backendcall.b-callio.com';

  /// Déclenche une push "chat_message" (on peut passer 1 ou N destinataires).
  Future<void> notifyNewMessage({
    required List<String> toUserIds, // <- 1 ou plusieurs
    required String roomId,
    String? messageId,
    required String fromId,
    required String fromName,
    String avatarUrl = '',
    String text = '',
    String contentType = 'text', // "text" | "image" | "audio" | "video"
    bool isGroup = false,
    String? sentAtIso, // DateTime.now().toUtc().toIso8601String()
  }) async {
    final uri = Uri.parse('$_base/api/notify-message');
    final body = {
      'toUserIds': toUserIds.length == 1 ? toUserIds.first : toUserIds,
      'roomId': roomId,
      'messageId': messageId,
      'fromId': fromId,
      'fromName': fromName,
      'avatarUrl': avatarUrl,
      'text': text,
      'sentAt': sentAtIso,
      'isGroup': isGroup,
      'contentType': contentType,
    };

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw Exception('notify-message failed: ${res.statusCode} ${res.body}');
    }
  }
}
