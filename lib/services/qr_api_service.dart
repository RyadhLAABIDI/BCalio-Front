import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/misc.dart';

class QrApiService {
  final String baseUrl; // ex: qrNodeUrl (ton serveur Node local)
  QrApiService({this.baseUrl = qrNodeUrl});

  Future<Map<String, dynamic>> getMyQr() async {
    final uid = await _getUserId();
    final r = await http.get(
      Uri.parse('$baseUrl/api/qr/me'),
      headers: {'x-user-id': uid},
    );
    if (r.statusCode != 200) {
      throw Exception('QR getMyQr failed: ${r.statusCode} ${r.body}');
    }
    return Map<String, dynamic>.from(json.decode(r.body));
    // => { token, text, expSeconds, mode }
  }

  /// Envoie tel quel le texte scanné (ex: "bcakio:qr-add:<JWT>" ou "<JWT>") à ton Node.
  /// Le Node gère le prefix et retourne { ok, contactId, profile? }.
  Future<Map<String, dynamic>> addByQrText(String textOrToken) async {
    final uid = await _getUserId();
    final r = await http.post(
      Uri.parse('$baseUrl/api/contacts/add-by-qr'),
      headers: {
        'x-user-id': uid,
        'Content-Type': 'application/json',
      },
      body: json.encode({'token': textOrToken}),
    );
    if (r.statusCode != 200) {
      throw Exception('QR addByQr failed: ${r.statusCode} ${r.body}');
    }
    return Map<String, dynamic>.from(json.decode(r.body));
  }

  Future<String> _getUserId() async {
    final p = await SharedPreferences.getInstance();
    final uid = p.getString('userId') ?? '';
    if (uid.isEmpty) throw Exception('No userId in prefs');
    return uid;
  }
}
