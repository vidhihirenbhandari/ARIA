import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/api_client.dart';
import '../../../shared/models/aria_event.dart';

class EventsRepository {
  final ApiClient _client;
  EventsRepository(this._client);

  Future<List<Event>> getPendingEvents() async {
    final response = await _client.get('/events', queryParameters: {'status': 'pending'});
    return (response.data['items'] as List).map((j) => Event.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<void> approveEvent(String eventId) async {
    await _client.post('/events/$eventId/approve');
  }

  Future<void> rejectEvent(String eventId) async {
    await _client.post('/events/$eventId/reject');
  }

  Future<Map<String, dynamic>> detectEventFromText(String text) async {
    final response = await _client.post('/events/detect', data: {'text': text});
    return response.data as Map<String, dynamic>;
  }
}

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository(ref.read(apiClientProvider));
});

// Provider for pending suggestions
final pendingSuggestionsProvider = FutureProvider<List<Event>>((ref) async {
  return ref.read(eventsRepositoryProvider).getPendingEvents();
});
