class PackingItem {
  final String id;
  final String name;
  final String emoji;
  final bool isAlwaysBring;
  final String? context; // 'rain' | 'travel' | 'longday' | 'meeting' | null = always
  final bool checked;
  final DateTime createdAt;

  const PackingItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.isAlwaysBring,
    this.context,
    this.checked = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'isAlwaysBring': isAlwaysBring,
        'context': context,
        'checked': checked,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PackingItem.fromJson(Map<String, dynamic> j) => PackingItem(
        id: j['id'] as String,
        name: j['name'] as String,
        emoji: j['emoji'] as String,
        isAlwaysBring: j['isAlwaysBring'] as bool? ?? true,
        context: j['context'] as String?,
        checked: j['checked'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  PackingItem copyWith({
    String? id,
    String? name,
    String? emoji,
    bool? isAlwaysBring,
    Object? context = _sentinel,
    bool? checked,
    DateTime? createdAt,
  }) =>
      PackingItem(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        isAlwaysBring: isAlwaysBring ?? this.isAlwaysBring,
        context: context == _sentinel ? this.context : context as String?,
        checked: checked ?? this.checked,
        createdAt: createdAt ?? this.createdAt,
      );
}

const Object _sentinel = Object();
