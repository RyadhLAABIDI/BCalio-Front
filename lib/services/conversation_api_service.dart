import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/conversation_model.dart';
import '../utils/misc.dart';

class ConversationApiService {
  /// Fetch Conversations
  Future<List<Conversation>> getConversations(String token) async {
    final url = Uri.parse('$baseUrl/mobile/conversations');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> conversationsJson = json.decode(response.body);
      debugPrint('Conversations fetched: $conversationsJson');
      final conversations = conversationsJson
          .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
          .toList();
      debugPrint('Parsed conversations userIds: ${conversations.map((c) => c.userIds).toList()}');
      return conversations;
    } else {
      throw Exception('Failed to fetch conversations: ${response.body}');
    }
  }

  /// Create 1:1 Conversation
  Future<Conversation> createConversation({
    required String token,
    required bool isGroup,
    required String userId,
  }) async {
    final url = Uri.parse('$baseUrl/mobile/conversations');
    debugPrint('Creating conversation with URL: $url');
    debugPrint('Request Body: {"isGroup": $isGroup, "userId": "$userId"}');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'isGroup': isGroup,
          'userId': userId,
        }),
      );

      debugPrint('Create Conversation Response Status: ${response.statusCode}');
      debugPrint('Create Conversation Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final conversation = Conversation.fromJson(json.decode(response.body));
        debugPrint('Conversation created with userIds: ${conversation.userIds}');
        return conversation;
      } else {
        throw Exception(
          'Failed to create conversation. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Exception occurred while creating conversation: $e');
      throw Exception('An error occurred while creating the conversation: $e');
    }
  }

  /// Create Group Conversation — conforme au contrat:
  /// POST /mobile/conversations
  /// {
  ///   "isGroup": true,
  ///   "name": "My Group",
  ///   "logo": "https://example.com/group-logo.png",
  ///   "members": [ { "value": "<id1>" }, { "value": "<id2>" } ]
  /// }
  Future<Conversation> createGroupConversation({
    required String token,
    required String name,
    String? logo,
    required List<String> memberIds, // liste d'ObjectId (hors créateur)
  }) async {
    final url = Uri.parse('$baseUrl/mobile/conversations');

    // Construire `members` comme demandé par l’API
    final membersPayload = memberIds.map((id) => {'value': id}).toList();

    // Ne pas envoyer de logo invalide (ex: file:///)
    String? safeLogo;
    if (logo != null && logo.trim().isNotEmpty && !logo.trim().startsWith('file:///')) {
      safeLogo = logo.trim();
    }

    final payload = <String, dynamic>{
      'isGroup': true,
      'name': name,
      if (safeLogo != null) 'logo': safeLogo,
      'members': membersPayload,
    };

    debugPrint('Create Group -> payload: ${json.encode(payload)}');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(payload),
      );

      debugPrint('Create Group Response Status: ${response.statusCode}');
      debugPrint('Create Group Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final map = json.decode(response.body) as Map<String, dynamic>;
        return Conversation.fromJson(map);
      } else {
        throw Exception(
          'Failed to create group conversation. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Exception in createGroupConversation: $e');
      throw Exception('An error occurred while creating the group conversation.');
    }
  }
  /// Mark Conversation as Seen
  Future<Conversation> markConversationAsSeen({
    required String token,
    required String conversationId,
  }) async {
    final url = Uri.parse('$baseUrl/mobile/conversations/$conversationId/seen');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      debugPrint('Mark Conversation As Seen Status: ${response.statusCode}');
      debugPrint('Mark Conversation As Seen Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['id'] != null) {
          return Conversation.fromJson(jsonResponse);
        } else {
          throw Exception('Invalid response: Missing conversation ID.');
        }
      } else {
        throw Exception(
          'Failed to mark conversation as seen. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Exception in markConversationAsSeen: $e');
      throw Exception('An error occurred while marking the conversation as seen.');
    }
  }

  /// Delete conversation by id
  Future<void> deleteConversation({
    required String token,
    required String conversationId,
  }) async {
    final url = Uri.parse('$baseUrl/mobile/conversations/$conversationId');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      debugPrint('Delete Conversation Status: ${response.statusCode}');
      debugPrint('Delete Conversation Body: ${response.body}');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to delete conversation. Status: ${response.statusCode}, Body: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Exception in deleteConversation: $e');
      throw Exception('An error occurred while deleting the conversation');
    }
  }
}
