import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/misc.dart'; // doit exposer `callServerBase` (ex: http://192.168.1.12:1906)

class InviteSmsService {
  final String base;
  InviteSmsService({this.base = callServerBase});

  /// Normalise (garde chiffres et +, convertit 00... -> +...)
  String normalize(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (s.startsWith('00')) s = '+${s.substring(2)}';
    return s;
  }

  /// Envoie une invitation à 1 numéro
  Future<bool> sendOne({
    required String token,
    required String phone,
    String? name,
  }) async {
    final url = Uri.parse('$base/api/invite-sms');
    final body = jsonEncode({
      'phone': phone,
      if (name != null && name.isNotEmpty) 'name': name,
    });

    if (kDebugMode) {
      print('[invite-sms] POST $url  phone=$phone name=$name');
    }

    final r = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (kDebugMode) {
      print('[invite-sms] status=${r.statusCode} body=${r.body}');
    }

    if (r.statusCode != 200) return false;
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final sent = (data['sent'] ?? 0) as int;
    return sent >= 1;
  }

  /// Envoie une invitation à plusieurs numéros
  Future<int> sendMany({
    required String token,
    required List<String> phones,
  }) async {
    final url = Uri.parse('$base/api/invite-sms');
    final body = jsonEncode({'phones': phones});

    if (kDebugMode) {
      print('[invite-sms] POST $url  phones=$phones');
    }

    final r = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
    );

    if (kDebugMode) {
      print('[invite-sms] status=${r.statusCode} body=${r.body}');
    }

    if (r.statusCode != 200) return 0;
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return (data['sent'] ?? 0) as int;
  }
}
