import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/habit.dart';
import '../services/local_storage.dart';

const _kHabitsKey = 'habits_list';

String _generateId() {
  final rand = Random();
  final ts = DateTime.now().millisecondsSinceEpoch;
  final suffix = rand.nextInt(99999).toString().padLeft(5, '0');
  return '${ts}_$suffix';
}

// ── Provider ──────────────────────────────────────────────────────────────

final habitsProvider =
    StateNotifierProvider<HabitsNotifier, List<Habit>>((ref) {
  final storage = ref.read(localStorageProvider);
  return HabitsNotifier(storage);
});

class HabitsNotifier extends StateNotifier<List<Habit>> {
  final LocalStorage _storage;

  HabitsNotifier(this._storage) : super([]) {
    _load();
  }

  void _load() {
    final raw = _storage.getList(_kHabitsKey);
    if (raw.isEmpty) {
      state = [];
      _persist();
    } else {
      state = raw.map(Habit.fromJson).toList();
    }
  }

  Future<void> _persist() async {
    await _storage.putList(_kHabitsKey, state.map((h) => h.toJson()).toList());
  }

  Future<void> addHabit(Habit habit) async {
    state = [...state, habit];
    await _persist();
  }

  Future<void> deleteHabit(String id) async {
    state = state.where((h) => h.id != id).toList();
    await _persist();
  }

  Future<void> toggleToday(String id) async {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    state = state.map((h) {
      if (h.id != id) return h;
      final dates = List<String>.from(h.completedDates);
      if (dates.contains(today)) {
        dates.remove(today);
      } else {
        dates.add(today);
      }
      return h.copyWith(completedDates: dates);
    }).toList();
    await _persist();
  }

  Future<void> updateHabit(Habit updated) async {
    state = state.map((h) => h.id == updated.id ? updated : h).toList();
    await _persist();
  }
}
