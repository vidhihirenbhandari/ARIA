class Subscription {
  final String id;
  final String name;
  final String? amountStr;
  final DateTime renewalDate;
  final String frequency; // 'weekly', 'monthly', 'yearly', 'custom', 'one_time'
  final int? customDays;
  final int alertDaysBefore;
  final String? notes;
  final String category; // 'app', 'streaming', 'utility', 'insurance', 'other'
  final bool isActive;
  final bool isAutoManaged; // true = sideload cert, cannot be edited
  final DateTime createdAt;

  const Subscription({
    required this.id,
    required this.name,
    this.amountStr,
    required this.renewalDate,
    this.frequency = 'monthly',
    this.customDays,
    this.alertDaysBefore = 2,
    this.notes,
    this.category = 'other',
    this.isActive = true,
    this.isAutoManaged = false,
    required this.createdAt,
  });

  int get daysUntilRenewal => renewalDate.difference(DateTime.now()).inDays;
  bool get isOverdue => daysUntilRenewal < 0;
  bool get isAlertSoon => !isOverdue && daysUntilRenewal <= alertDaysBefore;

  DateTime get nextRenewalDate {
    if (!isOverdue) return renewalDate;
    final now = DateTime.now();
    DateTime next = renewalDate;
    while (next.isBefore(now)) {
      switch (frequency) {
        case 'weekly':
          next = next.add(const Duration(days: 7));
          break;
        case 'monthly':
          next = DateTime(next.year, next.month + 1, next.day);
          break;
        case 'yearly':
          next = DateTime(next.year + 1, next.month, next.day);
          break;
        case 'custom':
          next = next.add(Duration(days: customDays ?? 30));
          break;
        default:
          return next;
      }
    }
    return next;
  }

  Subscription copyWith({
    String? id,
    String? name,
    String? amountStr,
    DateTime? renewalDate,
    String? frequency,
    int? customDays,
    int? alertDaysBefore,
    String? notes,
    String? category,
    bool? isActive,
    bool? isAutoManaged,
    DateTime? createdAt,
  }) {
    return Subscription(
      id: id ?? this.id,
      name: name ?? this.name,
      amountStr: amountStr ?? this.amountStr,
      renewalDate: renewalDate ?? this.renewalDate,
      frequency: frequency ?? this.frequency,
      customDays: customDays ?? this.customDays,
      alertDaysBefore: alertDaysBefore ?? this.alertDaysBefore,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      isAutoManaged: isAutoManaged ?? this.isAutoManaged,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amountStr': amountStr,
        'renewalDate': renewalDate.toIso8601String(),
        'frequency': frequency,
        'customDays': customDays,
        'alertDaysBefore': alertDaysBefore,
        'notes': notes,
        'category': category,
        'isActive': isActive,
        'isAutoManaged': isAutoManaged,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
        id: json['id'] as String,
        name: json['name'] as String,
        amountStr: json['amountStr'] as String?,
        renewalDate: DateTime.parse(json['renewalDate'] as String),
        frequency: json['frequency'] as String? ?? 'monthly',
        customDays: json['customDays'] as int?,
        alertDaysBefore: json['alertDaysBefore'] as int? ?? 2,
        notes: json['notes'] as String?,
        category: json['category'] as String? ?? 'other',
        isActive: json['isActive'] as bool? ?? true,
        isAutoManaged: json['isAutoManaged'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
