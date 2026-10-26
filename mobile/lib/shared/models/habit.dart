import 'package:flutter/material.dart';

class Habit {
  final String id;
  final String name;
  final String emoji;
  final String frequency; // 'daily', 'weekdays', 'weekends'
  final int targetCount;
  final List<String> completedDates; // ISO 'yyyy-MM-dd'
  final int color; // Color value stored as int
  final DateTime createdAt;

  const Habit({
    required this.id,
    required this.name,
    required this.emoji,
    required this.frequency,
    this.targetCount = 1,
    required this.completedDates,
    required this.color,
    required this.createdAt,
  });

  // ── Computed ──────────────────────────────────────────────────────────────

  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String _dateString(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool isCompletedToday() => completedDates.contains(_todayString());

  int currentStreak() {
    int streak = 0;
    DateTime cursor = DateTime.now();
    // If today is not completed, streaks may still count from yesterday
    if (!completedDates.contains(_dateString(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (true) {
      if (!completedDates.contains(_dateString(cursor))) break;
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double completionRate(int days) {
    if (days <= 0) return 0.0;
    int completed = 0;
    final now = DateTime.now();
    for (int i = 0; i < days; i++) {
      final d = now.subtract(Duration(days: i));
      if (completedDates.contains(_dateString(d))) completed++;
    }
    return completed / days;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'frequency': frequency,
        'targetCount': targetCount,
        'completedDates': completedDates,
        'color': color,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        name: json['name'] as String,
        emoji: json['emoji'] as String,
        frequency: json['frequency'] as String,
        targetCount: (json['targetCount'] as int?) ?? 1,
        completedDates: (json['completedDates'] as List<dynamic>)
            .map((e) => e as String)
            .toList(),
        color: json['color'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Habit copyWith({
    String? id,
    String? name,
    String? emoji,
    String? frequency,
    int? targetCount,
    List<String>? completedDates,
    int? color,
    DateTime? createdAt,
  }) =>
      Habit(
        id: id ?? this.id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        frequency: frequency ?? this.frequency,
        targetCount: targetCount ?? this.targetCount,
        completedDates: completedDates ?? this.completedDates,
        color: color ?? this.color,
        createdAt: createdAt ?? this.createdAt,
      );
}
