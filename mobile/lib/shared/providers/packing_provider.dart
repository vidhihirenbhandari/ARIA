import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/packing_item.dart';
import '../services/local_storage.dart';

const _kPackingKey = 'packing_items';
const _kContextsKey = 'packing_contexts';

final packingProvider =
    StateNotifierProvider<PackingNotifier, List<PackingItem>>((ref) {
  final storage = ref.read(localStorageProvider);
  return PackingNotifier(storage);
});

final activePackingContextsProvider =
    StateNotifierProvider<PackingContextsNotifier, Set<String>>((ref) {
  final storage = ref.read(localStorageProvider);
  return PackingContextsNotifier(storage);
});

// ── Packing items notifier ────────────────────────────────────────────────────

class PackingNotifier extends StateNotifier<List<PackingItem>> {
  final LocalStorage _storage;

  PackingNotifier(this._storage) : super([]) {
    _load();
  }

  void _load() {
    final raw = _storage.getList(_kPackingKey);
    if (raw.isEmpty) {
      _seedDefaults();
    } else {
      state = raw.map(PackingItem.fromJson).toList();
    }
  }

  void _seedDefaults() {
    final now = DateTime.now();
    state = [
      PackingItem(id: 'phone',   name: 'Phone',   emoji: '📱', isAlwaysBring: true,  createdAt: now),
      PackingItem(id: 'wallet',  name: 'Wallet',  emoji: '👛', isAlwaysBring: true,  createdAt: now),
      PackingItem(id: 'keys',    name: 'Keys',    emoji: '🔑', isAlwaysBring: true,  createdAt: now),
      PackingItem(id: 'umbrella',name: 'Umbrella',emoji: '☂️', isAlwaysBring: false, context: 'rain',    createdAt: now),
      PackingItem(id: 'id_card', name: 'ID Card', emoji: '🪪', isAlwaysBring: false, context: 'travel',  createdAt: now),
      PackingItem(id: 'charger', name: 'Charger', emoji: '🔌', isAlwaysBring: false, context: 'longday', createdAt: now),
      PackingItem(id: 'laptop',  name: 'Laptop',  emoji: '💼', isAlwaysBring: false, context: 'meeting', createdAt: now),
    ];
    _persist();
  }

  Future<void> _persist() async {
    await _storage.putList(_kPackingKey, state.map((i) => i.toJson()).toList());
  }

  Future<void> addItem(PackingItem item) async {
    state = [...state, item];
    await _persist();
  }

  Future<void> deleteItem(String id) async {
    state = state.where((i) => i.id != id).toList();
    await _persist();
  }

  Future<void> toggleChecked(String id) async {
    state = state.map((i) => i.id == id ? i.copyWith(checked: !i.checked) : i).toList();
    await _persist();
  }

  Future<void> resetForToday() async {
    state = state.map((i) => i.copyWith(checked: false)).toList();
    await _persist();
  }

  Future<void> updateItem(PackingItem updated) async {
    state = state.map((i) => i.id == updated.id ? updated : i).toList();
    await _persist();
  }
}

// ── Active contexts notifier ──────────────────────────────────────────────────

class PackingContextsNotifier extends StateNotifier<Set<String>> {
  final LocalStorage _storage;

  PackingContextsNotifier(this._storage) : super({}) {
    _load();
  }

  void _load() {
    final raw = _storage.get(_kContextsKey) as String?;
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      state = Set<String>.from(list.cast<String>());
    }
  }

  Future<void> _persist() async {
    await _storage.put(_kContextsKey, jsonEncode(state.toList()));
  }

  Future<void> toggleContext(String ctx) async {
    final next = Set<String>.from(state);
    if (next.contains(ctx)) {
      next.remove(ctx);
    } else {
      next.add(ctx);
    }
    state = next;
    await _persist();
  }
}
