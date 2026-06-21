import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/subscription.dart';
import '../services/local_storage.dart';

final subscriptionsProvider =
    StateNotifierProvider<SubscriptionsNotifier, List<Subscription>>((ref) {
  final storage = ref.watch(localStorageProvider);
  return SubscriptionsNotifier(storage);
});

class SubscriptionsNotifier extends StateNotifier<List<Subscription>> {
  final LocalStorage _storage;
  static const _storageKey = 'subscriptions_list';

  SubscriptionsNotifier(this._storage) : super([]) {
    _load();
  }

  void _load() {
    final raw = _storage.getList(_storageKey);
    if (raw.isEmpty) {
      _seedDefaults();
      return;
    }
    state = raw.map(Subscription.fromJson).toList();
    ensureSideloadEntry();
  }

  Future<void> _persist() async {
    await _storage.putList(_storageKey, state.map((s) => s.toJson()).toList());
  }

  void _seedDefaults() {
    final now = DateTime.now();
    state = [
      Subscription(
        id: 'netflix',
        name: 'Netflix',
        amountStr: '₹649/mo',
        renewalDate: DateTime(now.year, now.month + 1, 5),
        frequency: 'monthly',
        alertDaysBefore: 2,
        category: 'streaming',
        createdAt: now,
      ),
      Subscription(
        id: 'icloud',
        name: 'iCloud Storage',
        amountStr: '₹75/mo',
        renewalDate: DateTime(now.year, now.month, now.day + 8),
        frequency: 'monthly',
        alertDaysBefore: 2,
        category: 'utility',
        createdAt: now,
      ),
    ];
    ensureSideloadEntry();
    _persist();
  }

  // Creates or refreshes the sideload iOS certificate entry.
  // Call this from main.dart when the app launches after a fresh sideload.
  void ensureSideloadEntry({bool refresh = false}) {
    final raw = _storage.get('sideload_install_date') as String?;
    if (raw == null && !refresh) return;

    final installDate = raw != null ? DateTime.parse(raw) : DateTime.now();
    final renewalDate = installDate.add(const Duration(days: 7));

    final existingIndex = state.indexWhere((s) => s.id == 'sideload_cert');
    final entry = Subscription(
      id: 'sideload_cert',
      name: 'iOS App Certificate',
      amountStr: 'Free (re-sideload)',
      renewalDate: renewalDate,
      frequency: 'weekly',
      alertDaysBefore: 2,
      notes: 'Re-install via Sideloadly before this expires',
      category: 'app',
      isAutoManaged: true,
      createdAt: installDate,
    );

    if (existingIndex >= 0) {
      final updated = [...state];
      updated[existingIndex] = entry;
      state = updated;
    } else {
      state = [entry, ...state];
    }
    _persist();
  }

  Future<void> add(Subscription sub) async {
    state = [sub, ...state];
    await _persist();
  }

  Future<void> update(Subscription sub) async {
    state = state.map((s) => s.id == sub.id ? sub : s).toList();
    await _persist();
  }

  Future<void> delete(String id) async {
    state = state.where((s) => s.id != id).toList();
    await _persist();
  }

  Future<void> toggleActive(String id) async {
    state = state
        .map((s) => s.id == id ? s.copyWith(isActive: !s.isActive) : s)
        .toList();
    await _persist();
  }
}
