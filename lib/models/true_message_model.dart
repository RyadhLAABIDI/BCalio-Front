import 'true_user_model.dart';

class Message {
  final String id;
  final String body;
  final String? image;
  final String? audio;
  final String? video;
  final String? file;
  final String? type;
  final DateTime createdAt;
  final String conversationId;
  final String senderId;
  final User? sender;
  final List<User>? seenBy;
  final bool isFromAI;

  Message({
    required this.id,
    required this.body,
    this.image,
    this.audio,
    this.video,
    this.file,
    this.type,
    required this.createdAt,
    required this.conversationId,
    required this.senderId,
    this.sender,
    this.seenBy,
    this.isFromAI = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: (json['id'] ?? json['_id'] ?? '') as String,
      body: json['body'] ?? '',
      image: json['image'] as String?,
      audio: json['audio'] as String?,
      video: json['video'] as String?,
      file: json['file'] as String?,
      type: json['type'] ?? 'text',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      sender: json['sender'] != null ? User.fromJson(json['sender'] as Map<String, dynamic>) : null,
      seenBy: (json['seen'] as List<dynamic>?)?.map((u) => User.fromJson(u as Map<String, dynamic>)).toList(),
      isFromAI: json['isFromAI'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'body': body,
      'image': image,
      'audio': audio,
      'video': video,
      'file': file,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'conversationId': conversationId,
      'senderId': senderId,
      'sender': sender?.toJson(),
      'seen': seenBy?.map((u) => u.toJson()).toList(),
      'isFromAI': isFromAI,
    };
  }

  Message copyWith({
    String? id,
    String? body,
    String? image,
    String? audio,
    String? video,
    String? file,
    String? type,
    DateTime? createdAt,
    String? conversationId,
    String? senderId,
    User? sender,
    List<User>? seenBy,
    bool? isFromAI,
  }) {
    return Message(
      id: id ?? this.id,
      body: body ?? this.body,
      image: image ?? this.image,
      audio: audio ?? this.audio,
      video: video ?? this.video,
      file: file ?? this.file,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      sender: sender ?? this.sender,
      seenBy: seenBy ?? this.seenBy,
      isFromAI: isFromAI ?? this.isFromAI,
    );
  }
}
