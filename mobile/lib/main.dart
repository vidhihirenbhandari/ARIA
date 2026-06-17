import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'shared/services/local_storage.dart';
import 'shared/services/notification_service.dart';
import 'features/assistant/data/events_repository.dart';
import 'features/dashboard/data/briefing_repository.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  final storage = LocalStorage();
  await storage.init();

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
  ConsumerState<_AppWithNotifications> createState() =>
      _AppWithNotificationsState();
}

class _AppWithNotificationsState
    extends ConsumerState<_AppWithNotifications> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _initNotifications());
  }

  Future<void> _initNotifications() async {
    try {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.initialize(
        onMessage: _handleMessage,
        onMessageOpenedApp: _handleMessage,
      );
    } catch (_) {}
  }

  void _handleMessage(dynamic message) {
    final data = (message as Map<String, dynamic>?) ?? {};
    final type = data['type'] as String?;
    if (type == 'meeting_detected') ref.invalidate(pendingSuggestionsProvider);
    if (type == 'daily_briefing') ref.invalidate(dailyBriefingProvider);
    if (type == 'travel_detected') ref.invalidate(pendingSuggestionsProvider);
  }

  @override
  Widget build(BuildContext context) => const AriaApp();
}
