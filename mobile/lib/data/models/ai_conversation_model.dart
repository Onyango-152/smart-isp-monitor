/// AI Conversation models for chat with assistant
class AIConversationModel {
  final int id;
  final String title;
  final String createdAt;
  final String updatedAt;
  final int messageCount;
  final List<AIMessageModel> messages;

  const AIConversationModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    this.messages = const [],
  });

  factory AIConversationModel.fromJson(Map<String, dynamic> json) {
    return AIConversationModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'New Conversation',
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      messageCount: json['message_count'] as int? ?? 0,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => AIMessageModel.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'message_count': messageCount,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }
}

class AIMessageModel {
  final int id;
  final String role; // 'user' or 'assistant'
  final String content;
  final String timestamp;

  const AIMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory AIMessageModel.fromJson(Map<String, dynamic> json) {
    return AIMessageModel(
      id: json['id'] as int,
      role: json['role'] as String,
      content: json['content'] as String,
      timestamp: json['timestamp'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'timestamp': timestamp,
    };
  }
}
