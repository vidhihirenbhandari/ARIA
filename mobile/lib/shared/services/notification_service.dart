import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  Future<void> initialize({
    required Function(dynamic) onMessage,
    required Function(dynamic) onMessageOpenedApp,
  }) async {}

  Future<String?> getToken() async => null;
  Future<void> subscribeToTopic(String topic) async {}
  Future<void> unsubscribeFromTopic(String topic) async {}
}

final notificationServiceProvider =
    Provider<NotificationService>((_) => NotificationService());
