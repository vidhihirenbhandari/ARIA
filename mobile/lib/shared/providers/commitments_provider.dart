import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/commitment.dart';
import '../services/local_storage.dart';

class CommitmentsNotifier extends StateNotifier<List<Commitment>> {
  final LocalStorage _storage;
  static const _storageKey = 'commitments_list';

  CommitmentsNotifier(this._storage) : super([]) {
    loadFromStorage();
  }

  void loadFromStorage() {
    final raw = _storage.getList(_storageKey);
    if (raw.isEmpty) {
      // Seed with realistic examples on first load
      final now = DateTime.now();
      state = [
        Commitment(
          id: '1',
          text: 'Send the Q4 proposal document to Raj',
          person: 'Raj',
          direction: 'i_promised',
          dueDate: now.subtract(const Duration(days: 2)),
          createdAt: now.subtract(const Duration(days: 5)),
          source: 'chat',
        ),
        Commitment(
          id: '2',
          text: 'Share the design mockups for the landing page',
          person: 'Priya',
          direction: 'they_promised',
          dueDate: now.add(const Duration(days: 3)),
          createdAt: now.subtract(const Duration(days: 1)),
          source: 'inbox',
        ),
        Commitment(
          id: '3',
          text: 'Review the budget spreadsheet before Friday',
          person: 'Team',
          direction: 'i_promised',
          dueDate: now.add(const Duration(days: 4)),
          createdAt: now.subtract(const Duration(days: 2)),
          source: 'manual',
        ),
      ];
      saveToStorage();
    } else {
      state = raw.map(Commitment.fromJson).toList();
    }
  }

  Future<void> saveToStorage() async {
    await _storage.putList(_storageKey, state.map((c) => c.toJson()).toList());
  }

  Future<void> addCommitment(Commitment commitment) async {
    state = [...state, commitment];
    await saveToStorage();
  }

  Future<void> toggleComplete(String id) async {
    state = state.map((c) {
      if (c.id == id) return c.copyWith(isCompleted: !c.isCompleted);
      return c;
    }).toList();
    await saveToStorage();
  }

  Future<void> deleteCommitment(String id) async {
    state = state.where((c) => c.id != id).toList();
    await saveToStorage();
  }
}

final commitmentsProvider =
    StateNotifierProvider<CommitmentsNotifier, List<Commitment>>(
  (ref) => CommitmentsNotifier(ref.read(localStorageProvider)),
);
