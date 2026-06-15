enum MessageRole { user, assistant, system }
enum MessageType { text, voice, suggestion, action }

class Message {
  final String id;
  final String content;
  final MessageRole role;
  final MessageType type;
  final DateTime timestamp;
  final bool isStreaming;
  final Map<String, dynamic>? metadata;

  const Message({
    required this.id,
    required this.content,
    required this.role,
    this.type = MessageType.text,
    required this.timestamp,
    this.isStreaming = false,
    this.metadata,
  });

  bool get isUser => role == MessageRole.user;
  bool get isAssistant => role == MessageRole.assistant;

  Message copyWith({
    String? id,
    String? content,
    MessageRole? role,
    MessageType? type,
    DateTime? timestamp,
    bool? isStreaming,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      role: role ?? this.role,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'role': role.name,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'isStreaming': isStreaming,
    'metadata': metadata,
  };

  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: json['id'] as String,
    content: json['content'] as String,
    role: MessageRole.values.firstWhere(
      (e) => e.name == json['role'],
      orElse: () => MessageRole.user,
    ),
    type: MessageType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => MessageType.text,
    ),
    timestamp: DateTime.parse(json['timestamp'] as String),
    isStreaming: json['isStreaming'] as bool? ?? false,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
}

class Conversation {
  final String id;
  final List<Message> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? title;

  const Conversation({
    required this.id,
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
    this.title,
  });

  Conversation copyWith({
    String? id,
    List<Message>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
  }) {
    return Conversation(
      id: id ?? this.id,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
    );
  }
}
