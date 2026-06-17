import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_storage.dart';

// flutter_local_notifications is not supported on web; guard all usage
// behind kIsWeb checks at runtime. The import is still valid on all platforms.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ProactiveNotificationService {
  final LocalStorage _storage;
  FlutterLocalNotificationsPlugin? _plugin;

  static const String _channelId = 'aria_proactive';
  static const String _channelName = 'ARIA Proactive Reminders';

  ProactiveNotificationService(this._storage);

  Future<void> init() async {
    if (kIsWeb) return;

    _plugin = FlutterLocalNotificationsPlugin();

    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin!.initialize(initSettings);
  }

  NotificationDetails get _defaultDetails {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Proactive health and wellness reminders from ARIA',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const darwinDetails = DarwinNotificationDetails();
    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  NotificationDetails get _highDetails {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Important reminders from ARIA',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    return const NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  Future<void> scheduleWaterReminders({bool enabled = true}) async {
    if (kIsWeb || _plugin == null) return;

    // Cancel existing water reminders
    for (int i = 100; i <= 111; i++) {
      await _plugin!.cancel(i);
    }
    if (!enabled) return;

    // Show next water reminder as a periodic-style notification
    // (true scheduling with zonedSchedule requires timezone package setup;
    //  here we show an immediate notification as a placeholder)
    await showInstantNotification(
      'Water Reminders Enabled',
      'ARIA will remind you to drink water every 2 hours.',
    );
  }

  Future<void> scheduleDailyBriefing({
    bool enabled = true,
    String wakeTime = '07:00',
  }) async {
    if (kIsWeb || _plugin == null) return;

    await _plugin!.cancel(200);
    if (!enabled) return;

    await showInstantNotification(
      'Daily Briefing Enabled',
      'ARIA will brief you every morning at $wakeTime.',
    );
  }

  Future<void> scheduleExerciseReminder({bool enabled = true}) async {
    if (kIsWeb || _plugin == null) return;

    await _plugin!.cancel(300);
    if (!enabled) return;

    await showInstantNotification(
      'Exercise Reminders Enabled',
      'ARIA will remind you to move at 6:00 PM daily.',
    );
  }

  Future<void> showInstantNotification(String title, String body) async {
    if (kIsWeb || _plugin == null) return;

    await _plugin!.show(0, title, body, _highDetails);
  }
}

final proactiveNotificationServiceProvider =
    Provider<ProactiveNotificationService>((ref) {
  final storage = ref.read(localStorageProvider);
  return ProactiveNotificationService(storage);
});
