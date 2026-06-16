import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_constants.dart';

final localStorageProvider = Provider<LocalStorage>((ref) {
  return LocalStorage();
});

class LocalStorage {
  static const String _boxName = 'aria_storage';
  late Box _box;

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  // Auth
  String? getAuthToken() => _box.get(AppConstants.authTokenKey) as String?;
  String? getRefreshToken() =>
      _box.get(AppConstants.refreshTokenKey) as String?;

  Future<void> saveAuthToken(String token) async =>
      _box.put(AppConstants.authTokenKey, token);
  Future<void> saveRefreshToken(String token) async =>
      _box.put(AppConstants.refreshTokenKey, token);

  // User
  Map<String, dynamic>? getUser() {
    final data = _box.get(AppConstants.userKey);
    if (data == null) return null;
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> saveUser(Map<String, dynamic> user) async =>
      _box.put(AppConstants.userKey, user);

  // Onboarding
  bool isOnboardingComplete() =>
      _box.get(AppConstants.onboardingKey) as bool? ?? false;

  Future<void> setOnboardingComplete(bool value) async =>
      _box.put(AppConstants.onboardingKey, value);

  // Settings
  Map<String, dynamic> getSettings() {
    final data = _box.get(AppConstants.settingsKey);
    if (data == null) return {};
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async =>
      _box.put(AppConstants.settingsKey, settings);

  // Assistant name
  String getAssistantName() =>
      _box.get(AppConstants.assistantNameKey) as String? ??
      AppConstants.defaultAssistantName;

  Future<void> saveAssistantName(String name) async =>
      _box.put(AppConstants.assistantNameKey, name);

  // Theme
  String getTheme() => _box.get(AppConstants.themeKey) as String? ?? 'dark';
  Future<void> saveTheme(String theme) async =>
      _box.put(AppConstants.themeKey, theme);

  // Demo mode
  bool isDemoMode() => _box.get('_demo_mode') as bool? ?? false;
  Future<void> setDemoMode(bool value) async => _box.put('_demo_mode', value);

  // Generic
  Future<void> put(String key, dynamic value) async => _box.put(key, value);
  dynamic get(String key) => _box.get(key);
  Future<void> delete(String key) async => _box.delete(key);

  Future<void> clearAll() async => _box.clear();

  // JSON helpers
  Future<void> putJson(String key, Map<String, dynamic> data) async =>
      _box.put(key, jsonEncode(data));

  Map<String, dynamic>? getJson(String key) {
    final raw = _box.get(key) as String?;
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> putList(String key, List<Map<String, dynamic>> data) async =>
      _box.put(key, jsonEncode(data));

  List<Map<String, dynamic>> getList(String key) {
    final raw = _box.get(key) as String?;
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
