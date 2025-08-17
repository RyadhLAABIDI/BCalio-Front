import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/contact_model.dart';
import '../utils/misc.dart';

class ContactApiService {
  /// Récupère MES contacts (ceux ajoutés dans l’app)
  Future<List<Contact>> getContacts(String token) async {
    final url = Uri.parse('$baseUrl/mobile/contacts/me');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> contactsJson = json.decode(response.body);
      return contactsJson.map((json) => Contact.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch contacts: ${response.body}');
    }
  }

  /// Récupère TOUS les users (utile pour faire le matching téléphone)
  Future<List<Contact>> getAllContacts(String token) async {
    final url = Uri.parse('$baseUrl/mobile/users');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> contactsJson = json.decode(response.body);
      debugPrint('get all Contacts api====================: $contactsJson');
      return contactsJson.map((json) => Contact.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch contacts: ${response.body}');
    }
  }

  /// Ajoute un contact (via contactId)
  ///
  /// 🔧 Corrections importantes:
  /// - NE PLUS jeter d’exception si `message == "Contact added successfully"`
  /// - Toujours renvoyer un Contact COMPLET si possible :
  ///   * si `response.contact` existe → on le mappe
  ///   * sinon on tente un GET `/getuserbyid?id=...` pour compléter (nom/phone)
  ///   * en dernier recours on renvoie un contact minimal (id seul)
  Future<Contact> addContact(String token, String contactId) async {
    final url = Uri.parse('$baseUrl/mobile/contacts');
    debugPrint('Add Contact contactId: ========================$contactId');

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'contactId': contactId}),
    );

    debugPrint('Add Contact Response Status: ${response.statusCode}');
    debugPrint('Add Contact Response Body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Failed to add contact: ${response.body}');
    }

    final responseBody = json.decode(response.body);
    if (responseBody == null) {
      throw Exception('API response is null');
    }

    // 1) Le backend peut déjà renvoyer un objet `contact`
    if (responseBody is Map && responseBody.containsKey('contact')) {
      final jsonData = responseBody['contact'];
      return Contact.fromJson(jsonData);
    }

    // 2) Gérer les messages de succès sans objet `contact`
    final msg = (responseBody['message'] ?? '').toString();
    if (msg == 'Contact added successfully' || msg == 'Contact already added') {
      // Essayer de compléter avec /getuserbyid pour récupérer phone/name/image
      final filled = await _fetchUserAsContact(contactId);
      if (filled != null) return filled;

      // Dernier recours : renvoyer un contact minimal (évite "No Phone Number")
      return Contact(
        id: contactId,
        name: '',
        email: '',
        image: null,
        phoneNumber: '',
      );
    }

    // 3) Sinon, on considère que c’est une erreur côté API
    throw Exception(responseBody['message'] ?? 'Unknown API response');
  }

  /// Essaie de récupérer un user complet et le mapper en Contact
  Future<Contact?> _fetchUserAsContact(String contactId) async {
    try {
      final url = Uri.parse('$baseUrl/getuserbyid?id=$contactId');
      final r = await http.get(url);
      if (r.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(r.body);
        // Le JSON de ce endpoint correspond déjà à Contact.fromJson côté app
        return Contact.fromJson(data);
      }
    } catch (e) {
      debugPrint('fetchUserAsContact error: $e');
    }
    return null;
  }
}
