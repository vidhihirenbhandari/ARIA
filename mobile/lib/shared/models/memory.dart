enum MemoryCategory {
  preference,
  fact,
  relationship,
  goal,
  habit,
  note,
  reminder,
}

class Memory {
  final String id;
  final String content;
  final MemoryCategory category;
  final List<String> tags;
  final double importance;
  final DateTime createdAt;
  final DateTime? lastAccessed;
  final int accessCount;
  final String? sourceConversationId;

  const Memory({
    required this.id,
    required this.content,
    required this.category,
    this.tags = const [],
    this.importance = 0.5,
    required this.createdAt,
    this.lastAccessed,
    this.accessCount = 0,
    this.sourceConversationId,
  });

  Memory copyWith({
    String? id,
    String? content,
    MemoryCategory? category,
    List<String>? tags,
    double? importance,
    DateTime? createdAt,
    DateTime? lastAccessed,
    int? accessCount,
    String? sourceConversationId,
  }) {
    return Memory(
      id: id ?? this.id,
      content: content ?? this.content,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      importance: importance ?? this.importance,
      createdAt: createdAt ?? this.createdAt,
      lastAccessed: lastAccessed ?? this.lastAccessed,
      accessCount: accessCount ?? this.accessCount,
      sourceConversationId:
          sourceConversationId ?? this.sourceConversationId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'category': category.name,
    'tags': tags,
    'importance': importance,
    'createdAt': createdAt.toIso8601String(),
    'lastAccessed': lastAccessed?.toIso8601String(),
    'accessCount': accessCount,
    'sourceConversationId': sourceConversationId,
  };

  factory Memory.fromJson(Map<String, dynamic> json) => Memory(
    id: json['id'] as String,
    content: json['content'] as String,
    category: MemoryCategory.values.firstWhere(
      (e) => e.name == json['category'],
      orElse: () => MemoryCategory.note,
    ),
    tags: (json['tags'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    importance: (json['importance'] as num?)?.toDouble() ?? 0.5,
    createdAt: DateTime.parse(json['createdAt'] as String),
    lastAccessed: json['lastAccessed'] != null
        ? DateTime.parse(json['lastAccessed'] as String)
        : null,
    accessCount: json['accessCount'] as int? ?? 0,
    sourceConversationId: json['sourceConversationId'] as String?,
  );
}
