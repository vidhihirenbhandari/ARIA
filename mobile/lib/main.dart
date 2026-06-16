import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'shared/services/local_storage.dart';
import 'shared/services/notification_service.dart';
import 'features/assistant/data/events_repository.dart';
import 'features/dashboard/data/briefing_repository.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // System UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0D0D1A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize storage
  final storage = LocalStorage();
  await storage.init();

  // Try to initialize Firebase (won't crash if not configured)
  try {
    // await Firebase.initializeApp();
  } catch (_) {}

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
      ],
      child: const _AppWithNotifications(),
    ),
  );
}

class _AppWithNotifications extends ConsumerStatefulWidget {
  const _AppWithNotifications();

  @override
  ConsumerState<_AppWithNotifications> createState() => _AppWithNotificationsState();
}

class _AppWithNotificationsState extends ConsumerState<_AppWithNotifications> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initNotifications());
  }

  Future<void> _initNotifications() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.initialize(
        onMessage: _handleForegroundMessage,
        onMessageOpenedApp: _handleMessageOpenedApp,
      );
    } catch (_) {
      // FCM not configured — skip
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final type = message.data['type'] as String?;
    switch (type) {
      case 'meeting_detected':
        ref.invalidate(pendingSuggestionsProvider);
        break;
      case 'daily_briefing':
        ref.invalidate(dailyBriefingProvider);
        break;
      case 'travel_detected':
        // Navigation to travel screen happens via app router; invalidate providers
        ref.invalidate(pendingSuggestionsProvider);
        break;
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final type = message.data['type'] as String?;
    switch (type) {
      case 'meeting_detected':
        ref.invalidate(pendingSuggestionsProvider);
        break;
      case 'daily_briefing':
        ref.invalidate(dailyBriefingProvider);
        break;
      case 'travel_detected':
        ref.invalidate(pendingSuggestionsProvider);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AriaApp();
  }
}
