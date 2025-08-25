import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/contact_model.dart';
import '../utils/misc.dart';

class ContactApiService {
  /// Récupère MES contacts
  Future<List<Contact>> getContacts(String token) async {
    final url = Uri.parse('$baseUrl/mobile/contacts/me');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> contactsJson = json.decode(response.body);
      return contactsJson.map((json) => Contact.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch contacts: ${response.body}');
    }
  }

  /// Récupère TOUS les users (utile pour matching)
  Future<List<Contact>> getAllContacts(String token) async {
    final url = Uri.parse('$baseUrl/mobile/users');
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      final List<dynamic> contactsJson = json.decode(response.body);
      debugPrint('getAllContacts payload: ${contactsJson.length} users');
      return contactsJson.map((json) => Contact.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch contacts: ${response.body}');
    }
  }

  /// (Optionnel) Ajout via API centrale — pas utilisé par le flow QR
  Future<Contact> addContact(String token, String contactId) async {
    final url = Uri.parse('$baseUrl/mobile/contacts');
    debugPrint('Add Contact contactId: $contactId');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'contactId': contactId}),
    );

    debugPrint('Add Contact Status: ${response.statusCode}');
    debugPrint('Add Contact Body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to add contact: ${response.body}');
    }

    final body = json.decode(response.body);
    if (body == null) throw Exception('API response is null');

    if (body is Map && body.containsKey('contact')) {
      return Contact.fromJson(body['contact']);
    }

    final msg = (body['message'] ?? '').toString();
    if (msg == 'Contact added successfully' || msg == 'Contact already added') {
      return Contact(id: contactId, name: '', email: '', image: null, phoneNumber: '');
    }

    throw Exception(body['message'] ?? 'Unknown API response');
  }

  /// Récupère le user (Contact) par ID, pour compléter numéro/nom/email.
  Future<Contact?> getUserById(String token, String userId) async {
    // Essais directs connus
    for (final candidate in <Uri>[
      Uri.parse('$baseUrl/mobile/users/$userId'),
      Uri.parse('$baseUrl/mobile/users?id=$userId'),
      Uri.parse('$baseUrl/mobile/users?ids=$userId'),
    ]) {
      try {
        final r = await http.get(candidate, headers: {'Authorization': 'Bearer $token'});
        if (r.statusCode == 200) {
          final data = json.decode(r.body);
          if (data is Map<String, dynamic>) {
            return Contact.fromJson(data);
          } else if (data is List && data.isNotEmpty) {
            final found = data.firstWhere(
              (e) => (e is Map && (e['id']?.toString() == userId)),
              orElse: () => null,
            );
            if (found is Map<String, dynamic>) {
              return Contact.fromJson(found);
            }
          }
        }
      } catch (e) {
        debugPrint('getUserById try ${candidate.toString()} error: $e');
      }
    }

    // Fallback: liste complète
    try {
      final rAll = await http.get(
        Uri.parse('$baseUrl/mobile/users'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (rAll.statusCode == 200) {
        final data = json.decode(rAll.body);
        if (data is List) {
          final match = data.cast<Map<String, dynamic>?>().firstWhere(
                (m) => m != null && (m!['id']?.toString() == userId),
                orElse: () => null,
              );
          if (match != null) return Contact.fromJson(match);
        }
      }
    } catch (e) {
      debugPrint('getUserById fallback /mobile/users error: $e');
    }

    return null;
  }
}
