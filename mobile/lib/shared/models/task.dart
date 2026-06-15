enum TaskPriority { low, medium, high, urgent }
enum TaskStatus { todo, inProgress, done, cancelled }

class Task {
  final String id;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime? dueDate;
  final List<String> tags;
  final String? projectId;
  final bool aiGenerated;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    this.dueDate,
    this.tags = const [],
    this.projectId,
    this.aiGenerated = false,
    required this.createdAt,
    this.completedAt,
  });

  bool get isCompleted => status == TaskStatus.done;
  bool get isOverdue =>
      dueDate != null && dueDate!.isBefore(DateTime.now()) && !isCompleted;

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? dueDate,
    List<String>? tags,
    String? projectId,
    bool? aiGenerated,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      tags: tags ?? this.tags,
      projectId: projectId ?? this.projectId,
      aiGenerated: aiGenerated ?? this.aiGenerated,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'priority': priority.name,
    'status': status.name,
    'dueDate': dueDate?.toIso8601String(),
    'tags': tags,
    'projectId': projectId,
    'aiGenerated': aiGenerated,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    priority: TaskPriority.values.firstWhere(
      (e) => e.name == json['priority'],
      orElse: () => TaskPriority.medium,
    ),
    status: TaskStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => TaskStatus.todo,
    ),
    dueDate: json['dueDate'] != null
        ? DateTime.parse(json['dueDate'] as String)
        : null,
    tags: (json['tags'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [],
    projectId: json['projectId'] as String?,
    aiGenerated: json['aiGenerated'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'] as String)
        : null,
  );
}
