import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/misc.dart';

class PushApiService {
  /// Base URL du serveur Node (centralisée)
  /// Exemple: http://192.168.1.25:1906
  final String base;
  const PushApiService({this.base = callServerBaseUrl});

  /// Construit une URI sûre à partir de [base] + [path]
  Uri _u(String path) {
    final b = base.trim();            // évite les %20
    final u = Uri.parse(b);
    return u.replace(path: path.startsWith('/') ? path : '/$path');
  }

  Future<void> registerToken({
    required String userId,
    required String fcmToken,
  }) async {
    final res = await http.post(
      _u('/push/register'),           // ✅ plus de /api, correspond à ton serveur
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'fcmToken': fcmToken}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('registerToken failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> unregisterToken({
    required String userId,
    required String fcmToken,
  }) async {
    final res = await http.post(
      _u('/push/unregister'),         // ✅ idem
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'fcmToken': fcmToken}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('unregisterToken failed: ${res.statusCode} ${res.body}');
    }
  }
}
