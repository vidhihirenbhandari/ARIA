import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage.dart';

class ThemeNotifier extends StateNotifier<int> {
  final LocalStorage _storage;

  ThemeNotifier(this._storage) : super(_storage.getThemeIndex());

  void setTheme(int index) {
    state = index;
    _storage.saveThemeIndex(index);
  }
}

final themeIndexProvider = StateNotifierProvider<ThemeNotifier, int>(
  (ref) => ThemeNotifier(ref.read(localStorageProvider)),
);
