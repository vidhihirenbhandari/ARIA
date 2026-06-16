import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/services/local_storage.dart';
import '../../../shared/models/aria_event.dart';
import '../../../shared/demo/demo_data.dart';

class EventsRepository {
  final ApiClient _client;
  final bool isDemoMode;
  final List<Event> _demoEvents;

  EventsRepository(this._client, {this.isDemoMode = false})
      : _demoEvents = isDemoMode ? List.from(DemoData.pendingEvents) : [];

  Future<List<Event>> getPendingEvents() async {
    if (isDemoMode) return List.from(_demoEvents);
    final response = await _client.get('/events', queryParameters: {'status': 'pending'});
    return (response.data['items'] as List).map((j) => Event.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> approveEvent(String eventId) async {
    if (isDemoMode) {
      _demoEvents.removeWhere((e) => e.id == eventId);
      return;
    }
    await _client.post('/events/$eventId/approve');
  }

  Future<void> rejectEvent(String eventId) async {
    if (isDemoMode) {
      _demoEvents.removeWhere((e) => e.id == eventId);
      return;
    }
    await _client.post('/events/$eventId/reject');
  }

  Future<Map<String, dynamic>> detectEventFromText(String text) async {
    if (isDemoMode) return {'detected': false};
    final response = await _client.post('/events/detect', data: {'text': text});
    return response.data as Map<String, dynamic>;
  }
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  final storage = ref.read(localStorageProvider);
  return EventsRepository(ref.read(apiClientProvider), isDemoMode: storage.isDemoMode());
});

// Provider for pending suggestions
final pendingSuggestionsProvider = FutureProvider<List<Event>>((ref) async {
  return ref.read(eventsRepositoryProvider).getPendingEvents();
});
