import 'dart:convert';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:http/http.dart' as http;
import '../utils/misc.dart';

class ContactsSyncService {
  final String base;
  ContactsSyncService({this.base = callServerBase}); // ex: http://192.168.1.12:1906

  /// Normalisation identique au backend:
  /// - on garde uniquement les chiffres
  /// - on tronque aux 12 derniers si trop long
  String _norm(String s) {
    final d = s.replaceAll(RegExp(r'\D+'), '');
    return d.length > 12 ? d.substring(d.length - 12) : d;
  }

  /// Envoie les contacts du téléphone vers le serveur local:
  /// POST /api/contacts/sync-phone
  /// headers: Authorization: Bearer <token>
  /// body: { items: [{ name?, phone }, ...] }
  Future<({int saved, DateTime? updatedAt})> syncPhoneContacts(String token) async {
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) throw Exception('Permission contacts refusée');

    final contacts = await FlutterContacts.getContacts(withProperties: true);

    final seen = <String>{};
    final items = <Map<String, String?>>[];

    for (final c in contacts) {
      if (c.phones.isEmpty) continue;
      final ph = _norm(c.phones.first.number);
      if (ph.isEmpty || seen.contains(ph)) continue;
      seen.add(ph);
      items.add({'name': c.displayName, 'phone': ph}); // <-- "phone" (pas phoneNumber)
    }

    final url = Uri.parse('$base/api/contacts/sync-phone'); // <-- route exacte
    final resp = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'items': items}), // <-- "items" (pas "contacts")
    );

    if (resp.statusCode != 200) {
      throw Exception('sync-phone failed: ${resp.statusCode} ${resp.body}');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final saved = (data['stored'] ?? data['saved'] ?? 0) as int;

    // Le backend ne renvoie pas updatedAt → on met "maintenant" pour l’UI
    return (saved: saved, updatedAt: DateTime.now());
  }
}
