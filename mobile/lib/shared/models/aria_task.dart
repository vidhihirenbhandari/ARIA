class AriaTask {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String priority; // low | medium | high | urgent
  final String status;   // pending | in_progress | completed | cancelled
  final DateTime? dueDate;
  final String source;   // manual | memory | ai | integration
  final List<String> tags;
  final DateTime? completedAt;

  const AriaTask({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.priority = 'medium',
    this.status = 'pending',
    this.dueDate,
    this.source = 'manual',
    this.tags = const [],
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now()) && !isCompleted;

  AriaTask copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? priority,
    String? status,
    DateTime? dueDate,
    String? source,
    List<String>? tags,
    DateTime? completedAt,
  }) {
    return AriaTask(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      source: source ?? this.source,
      tags: tags ?? this.tags,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory AriaTask.fromJson(Map<String, dynamic> json) => AriaTask(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        priority: json['priority'] as String? ?? 'medium',
        status: json['status'] as String? ?? 'pending',
        dueDate: json['due_date'] != null
            ? DateTime.parse(json['due_date'] as String)
            : null,
        source: json['source'] as String? ?? 'manual',
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'priority': priority,
        'status': status,
        'due_date': dueDate?.toIso8601String(),
        'source': source,
        'tags': tags,
        'completed_at': completedAt?.toIso8601String(),
      };
}
