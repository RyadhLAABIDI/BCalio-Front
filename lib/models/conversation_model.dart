import 'package:flutter/material.dart';
import 'true_message_model.dart';
import 'true_user_model.dart';

class Conversation {
  final String id;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? name;
  final bool? isGroup;
  final String? logo;
  final List<String> messagesIds;
  final List<String> userIds;
  final List<User> users;
  final List<Message> messages;

  Conversation({
    required this.id,
    required this.createdAt,
    this.lastMessageAt,
    this.name,
    this.isGroup,
    this.logo,
    required this.messagesIds,
    required this.userIds,
    required this.users,
    required this.messages,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    print('Parsing Conversation ID: ${json['id']}');
    if (json['id'] == null) {
      throw Exception('Invalid API response: Conversation ID is null.');
    }

    final userIds = (json['userIds'] as List<dynamic>? ?? [])
        .map((e) => e is String ? e : (e is Map ? e['value']?.toString() ?? '' : e.toString()))
        .toList();
    if (!(json['isGroup'] ?? false) && userIds.length < 2) {
      print('Warning: Conversation ${json['id']} has insufficient userIds: $userIds');
    }

    return Conversation(
      id: json['id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'] as String)
          : null,
      name: json['name'] as String?,
      isGroup: json['isGroup'] as bool?,
      logo: json['logo'] as String?,
      messagesIds: (json['messagesIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      userIds: userIds,
      users: (json['users'] as List<dynamic>? ?? [])
          .map((userJson) => User.fromJson(userJson as Map<String, dynamic>))
          .toList(),
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((messageJson) => Message.fromJson(messageJson as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'name': name,
      'isGroup': isGroup,
      'logo': logo,
      'messagesIds': messagesIds,
      'userIds': userIds,
      'users': users.map((user) => user.toJson()).toList(),
      'messages': messages.map((message) => message.toJson()).toList(),
    };
  }

  Conversation copyWith({
    String? id,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    String? name,
    bool? isGroup,
    String? logo,
    List<String>? messagesIds,
    List<String>? userIds,
    List<User>? users,
    List<Message>? messages,
  }) {
    return Conversation(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      name: name ?? this.name,
      isGroup: isGroup ?? this.isGroup,
      logo: logo ?? this.logo,
      messagesIds: messagesIds ?? this.messagesIds,
      userIds: userIds ?? this.userIds,
      users: users ?? this.users,
      messages: messages ?? this.messages,
    );
  }
}
