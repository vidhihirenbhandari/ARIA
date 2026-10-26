import 'package:flutter_riverpod/flutter_riverpod.dart';

class PermissionsState {
  final bool calendarAccess;
  final bool whatsappAccess;
  final bool emailAccess;
  final bool smsAccess;
  final bool callLogAccess;
  final bool locationAccess;
  final bool memoryStorage;
  final bool travelDetection;
  final double suggestionThreshold;

  const PermissionsState({
    this.calendarAccess = true,
    this.whatsappAccess = false,
    this.emailAccess = true,
    this.smsAccess = false,
    this.callLogAccess = false,
    this.locationAccess = false,
    this.memoryStorage = true,
    this.travelDetection = true,
    this.suggestionThreshold = 0.7,
  });

  PermissionsState copyWith({
    bool? calendarAccess,
    bool? whatsappAccess,
    bool? emailAccess,
    bool? smsAccess,
    bool? callLogAccess,
    bool? locationAccess,
    bool? memoryStorage,
    bool? travelDetection,
    double? suggestionThreshold,
  }) {
    return PermissionsState(
      calendarAccess: calendarAccess ?? this.calendarAccess,
      whatsappAccess: whatsappAccess ?? this.whatsappAccess,
      emailAccess: emailAccess ?? this.emailAccess,
      smsAccess: smsAccess ?? this.smsAccess,
      callLogAccess: callLogAccess ?? this.callLogAccess,
      locationAccess: locationAccess ?? this.locationAccess,
      memoryStorage: memoryStorage ?? this.memoryStorage,
      travelDetection: travelDetection ?? this.travelDetection,
      suggestionThreshold: suggestionThreshold ?? this.suggestionThreshold,
    );
  }
}

class PermissionsNotifier extends StateNotifier<PermissionsState> {
  PermissionsNotifier() : super(const PermissionsState());

  void toggle(String key) {
    state = switch (key) {
      'calendar' => state.copyWith(calendarAccess: !state.calendarAccess),
      'whatsapp' => state.copyWith(whatsappAccess: !state.whatsappAccess),
      'email' => state.copyWith(emailAccess: !state.emailAccess),
      'sms' => state.copyWith(smsAccess: !state.smsAccess),
      'callLog' => state.copyWith(callLogAccess: !state.callLogAccess),
      'location' => state.copyWith(locationAccess: !state.locationAccess),
      'memory' => state.copyWith(memoryStorage: !state.memoryStorage),
      'travel' => state.copyWith(travelDetection: !state.travelDetection),
      _ => state,
    };
  }

  void setThreshold(double value) {
    state = state.copyWith(suggestionThreshold: value);
  }
}

final permissionsProvider =
    StateNotifierProvider<PermissionsNotifier, PermissionsState>(
  (_) => PermissionsNotifier(),
);

class SettingsState {
  final String assistantName;
  final bool notificationsEnabled;
  final bool focusModeEnabled;
  final bool dailyBriefingEnabled;
  final String briefingTime;

  const SettingsState({
    this.assistantName = 'ARIA',
    this.notificationsEnabled = true,
    this.focusModeEnabled = true,
    this.dailyBriefingEnabled = true,
    this.briefingTime = '07:00',
  });

  SettingsState copyWith({
    String? assistantName,
    bool? notificationsEnabled,
    bool? focusModeEnabled,
    bool? dailyBriefingEnabled,
    String? briefingTime,
  }) {
    return SettingsState(
      assistantName: assistantName ?? this.assistantName,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      focusModeEnabled: focusModeEnabled ?? this.focusModeEnabled,
      dailyBriefingEnabled: dailyBriefingEnabled ?? this.dailyBriefingEnabled,
      briefingTime: briefingTime ?? this.briefingTime,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void setAssistantName(String name) => state = state.copyWith(assistantName: name);
  void toggleNotifications() =>
      state = state.copyWith(notificationsEnabled: !state.notificationsEnabled);
  void toggleFocusMode() =>
      state = state.copyWith(focusModeEnabled: !state.focusModeEnabled);
  void toggleDailyBriefing() =>
      state = state.copyWith(dailyBriefingEnabled: !state.dailyBriefingEnabled);
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);
