class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final String type;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json["_id"],
      conversationId: json["conversationId"],
      senderId: json["senderId"],
      content: json["content"],
      type: json["type"],
      timestamp: DateTime.parse(json["timestamp"]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "_id": id,
      "conversationId": conversationId,
      "senderId": senderId,
      "content": content,
      "type": type,
      "timestamp": timestamp.toIso8601String(),
    };
  }
}
