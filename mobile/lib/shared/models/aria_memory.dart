class AriaMemory {
  final String id;
  final String userId;
  final String content;
  final List<String> tags;
  final List<String> peopleMentioned;
  final DateTime? eventDate;
  final double importanceScore;
  final DateTime createdAt;

  const AriaMemory({
    required this.id,
    required this.userId,
    required this.content,
    this.tags = const [],
    this.peopleMentioned = const [],
    this.eventDate,
    this.importanceScore = 0.5,
    required this.createdAt,
  });

  AriaMemory copyWith({
    String? id,
    String? userId,
    String? content,
    List<String>? tags,
    List<String>? peopleMentioned,
    DateTime? eventDate,
    double? importanceScore,
    DateTime? createdAt,
  }) {
    return AriaMemory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      peopleMentioned: peopleMentioned ?? this.peopleMentioned,
      eventDate: eventDate ?? this.eventDate,
      importanceScore: importanceScore ?? this.importanceScore,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AriaMemory.fromJson(Map<String, dynamic> json) => AriaMemory(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        content: json['content'] as String,
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        peopleMentioned: (json['people_mentioned'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        eventDate: json['event_date'] != null
            ? DateTime.parse(json['event_date'] as String)
            : null,
        importanceScore:
            (json['importance_score'] as num?)?.toDouble() ?? 0.5,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'content': content,
        'tags': tags,
        'people_mentioned': peopleMentioned,
        'event_date': eventDate?.toIso8601String(),
        'importance_score': importanceScore,
        'created_at': createdAt.toIso8601String(),
      };
}
