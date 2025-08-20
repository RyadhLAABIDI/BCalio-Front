import 'dart:convert';
import 'package:http/http.dart' as http;

class PushApiService {
  // ⚠️ Remplace par l’IP/host de TON serveur Node
  static const String base = 'http://192.168.1.26';

  Future<void> registerToken({
    required String userId,
    required String fcmToken,
  }) async {
    final res = await http.post(
      Uri.parse('$base/api/push/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'fcmToken': fcmToken}),
    );

    if (res.statusCode != 200) {
      throw Exception(
        'registerToken failed: ${res.statusCode} ${res.body}',
      );
    }
  }

  Future<void> unregisterToken({
    required String userId,
    required String fcmToken,
  }) async {
    final res = await http.post(
      Uri.parse('$base/api/push/unregister'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'fcmToken': fcmToken}),
    );

    if (res.statusCode != 200) {
      throw Exception(
        'unregisterToken failed: ${res.statusCode} ${res.body}',
      );
    }
  }
}
