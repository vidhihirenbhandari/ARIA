import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/watch_item.dart';
import '../services/local_storage.dart';

const _kKey = 'watch_list';

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, List<WatchItem>>((ref) {
  final storage = ref.read(localStorageProvider);
  return WatchlistNotifier(storage);
});

class WatchlistNotifier extends StateNotifier<List<WatchItem>> {
  final LocalStorage _storage;

  WatchlistNotifier(this._storage) : super([]) {
    _load();
  }

  void _load() {
    final raw = _storage.getList(_kKey);
    if (raw.isEmpty) {
      _seed();
    } else {
      state = raw.map((e) => WatchItem.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  void _seed() {
    final now = DateTime.now();
    state = [
      WatchItem(
        id: 'w1',
        title: 'IndiGo 6E-204',
        detail: 'Mumbai → Delhi, 14 Nov',
        type: WatchType.flight,
        alertDate: now.add(const Duration(days: 2)),
        createdAt: now,
      ),
      WatchItem(
        id: 'w2',
        title: 'Tax filing deadline',
        detail: 'ITR due 31 Dec',
        type: WatchType.deadline,
        alertDate: now.add(const Duration(days: 60)),
        createdAt: now,
      ),
      WatchItem(
        id: 'w3',
        title: 'MacBook Pro M4',
        detail: 'Watching for discount',
        type: WatchType.price,
        createdAt: now,
      ),
    ];
    _persist();
  }

  Future<void> _persist() async {
    await _storage.putList(_kKey, state.map((w) => w.toJson()).toList());
  }

  Future<void> addItem(WatchItem item) async {
    state = [item, ...state];
    await _persist();
  }

  Future<void> deleteItem(String id) async {
    state = state.where((w) => w.id != id).toList();
    await _persist();
  }

  Future<void> resolveItem(String id) async {
    state = state.map((w) => w.id == id ? w.copyWith(isResolved: true) : w).toList();
    await _persist();
  }

  Future<void> updateStatus(String id, String status) async {
    state = state.map((w) => w.id == id ? w.copyWith(status: status) : w).toList();
    await _persist();
  }
}
