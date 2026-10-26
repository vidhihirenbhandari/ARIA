import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../services/local_storage.dart';

const _kStorageKey = 'expenses_list';

class ExpensesNotifier extends StateNotifier<List<Expense>> {
  final LocalStorage _storage;

  ExpensesNotifier(this._storage) : super([]) {
    _load();
  }

  void _load() {
    final raw = _storage.getList(_kStorageKey);
    if (raw.isEmpty) {
      _seedSampleData();
      return;
    }
    state = raw.map((e) => Expense.fromJson(e)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  void _seedSampleData() {
    final now = DateTime.now();
    final samples = [
      Expense(
        id: 'seed_1',
        title: 'Swiggy Order',
        amount: 450.0,
        category: 'food',
        date: now.subtract(const Duration(days: 1)),
        note: 'Dinner from Punjabi Tadka',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      Expense(
        id: 'seed_2',
        title: 'Uber Ride',
        amount: 280.0,
        category: 'transport',
        date: now.subtract(const Duration(days: 3)),
        note: 'Office commute',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      Expense(
        id: 'seed_3',
        title: 'Electricity Bill',
        amount: 2400.0,
        category: 'bills',
        date: now.subtract(const Duration(days: 7)),
        note: 'BSES monthly bill',
        createdAt: now.subtract(const Duration(days: 7)),
      ),
      Expense(
        id: 'seed_4',
        title: 'Myntra Shopping',
        amount: 1850.0,
        category: 'shopping',
        date: now.subtract(const Duration(days: 12)),
        note: 'Casual t-shirts',
        createdAt: now.subtract(const Duration(days: 12)),
      ),
      Expense(
        id: 'seed_5',
        title: 'Pharmacy',
        amount: 320.0,
        category: 'health',
        date: now.subtract(const Duration(days: 18)),
        note: 'Monthly medicines',
        createdAt: now.subtract(const Duration(days: 18)),
      ),
    ];
    state = samples;
    _persist();
  }

  void _persist() {
    _storage.putList(_kStorageKey, state.map((e) => e.toJson()).toList());
  }

  void addExpense(Expense expense) {
    state = [expense, ...state]..sort((a, b) => b.date.compareTo(a.date));
    _persist();
  }

  void updateExpense(Expense updated) {
    state = state.map((e) => e.id == updated.id ? updated : e).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _persist();
  }

  void deleteExpense(String id) {
    state = state.where((e) => e.id != id).toList();
    _persist();
  }

  double totalThisMonth() {
    final now = DateTime.now();
    return state
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double totalByCategory(String category) {
    return state
        .where((e) => e.category == category)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  List<Expense> expensesThisMonth() {
    final now = DateTime.now();
    return state
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
  }
}

final expensesProvider =
    StateNotifierProvider<ExpensesNotifier, List<Expense>>((ref) {
  final storage = ref.watch(localStorageProvider);
  return ExpensesNotifier(storage);
});
