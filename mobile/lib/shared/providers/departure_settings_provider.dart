import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage.dart';

class DepartureSettings {
  final int defaultCommuteMinutes;
  final Map<String, int> eventOverrides; // eventId -> commuteMinutes

  const DepartureSettings({
    this.defaultCommuteMinutes = 30,
    this.eventOverrides = const {},
  });

  DepartureSettings copyWith({
    int? defaultCommuteMinutes,
    Map<String, int>? eventOverrides,
  }) =>
      DepartureSettings(
        defaultCommuteMinutes:
            defaultCommuteMinutes ?? this.defaultCommuteMinutes,
        eventOverrides: eventOverrides ?? this.eventOverrides,
      );

  Map<String, dynamic> toJson() => {
        'defaultCommuteMinutes': defaultCommuteMinutes,
        'eventOverrides': eventOverrides.map((k, v) => MapEntry(k, v)),
      };

  factory DepartureSettings.fromJson(Map<String, dynamic> json) =>
      DepartureSettings(
        defaultCommuteMinutes:
            (json['defaultCommuteMinutes'] as int?) ?? 30,
        eventOverrides: (json['eventOverrides'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      );
}

class DepartureSettingsNotifier extends StateNotifier<DepartureSettings> {
  static const _key = 'departure_settings';
  final LocalStorage _storage;

  DepartureSettingsNotifier(this._storage) : super(const DepartureSettings()) {
    _load();
  }

  void _load() {
    final raw = _storage.getJson(_key);
    if (raw != null) {
      state = DepartureSettings.fromJson(raw);
    }
  }

  Future<void> setDefaultCommute(int minutes) async {
    state = state.copyWith(defaultCommuteMinutes: minutes);
    await _storage.putJson(_key, state.toJson());
  }

  Future<void> setEventCommute(String eventId, int minutes) async {
    final overrides = Map<String, int>.from(state.eventOverrides)
      ..[eventId] = minutes;
    state = state.copyWith(eventOverrides: overrides);
    await _storage.putJson(_key, state.toJson());
  }

  int commuteForEvent(String eventId) =>
      state.eventOverrides[eventId] ?? state.defaultCommuteMinutes;
}

final departureSettingsProvider =
    StateNotifierProvider<DepartureSettingsNotifier, DepartureSettings>(
  (ref) => DepartureSettingsNotifier(ref.read(localStorageProvider)),
);
