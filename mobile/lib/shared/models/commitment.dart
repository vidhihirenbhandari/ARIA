class Commitment {
  final String id;
  final String text;
  final String person;
  final String direction; // 'i_promised' or 'they_promised'
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime createdAt;
  final String source; // 'inbox', 'chat', 'manual'

  const Commitment({
    required this.id,
    required this.text,
    required this.person,
    required this.direction,
    this.dueDate,
    this.isCompleted = false,
    required this.createdAt,
    this.source = 'manual',
  });

  Commitment copyWith({
    String? id,
    String? text,
    String? person,
    String? direction,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? createdAt,
    String? source,
  }) {
    return Commitment(
      id: id ?? this.id,
      text: text ?? this.text,
      person: person ?? this.person,
      direction: direction ?? this.direction,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'person': person,
        'direction': direction,
        'due_date': dueDate?.toIso8601String(),
        'is_completed': isCompleted,
        'created_at': createdAt.toIso8601String(),
        'source': source,
      };

  factory Commitment.fromJson(Map<String, dynamic> json) => Commitment(
        id: json['id'] as String,
        text: json['text'] as String,
        person: json['person'] as String? ?? '',
        direction: json['direction'] as String? ?? 'i_promised',
        dueDate: json['due_date'] != null
            ? DateTime.parse(json['due_date'] as String)
            : null,
        isCompleted: json['is_completed'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        source: json['source'] as String? ?? 'manual',
      );
}
