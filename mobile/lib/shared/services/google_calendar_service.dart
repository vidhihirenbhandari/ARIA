import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import 'package:http/http.dart' as http;
import '../models/aria_event.dart';

class GoogleCalendarService {
  Future<List<Event>> fetchTodayEvents(GoogleSignInAccount account) async {
    try {
      final headers = await account.authHeaders;
      final client = _AuthedClient(headers);
      final calApi = gcal.CalendarApi(client);

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc();

      final result = await calApi.events.list(
        'primary',
        timeMin: startOfDay,
        timeMax: endOfDay,
        singleEvents: true,
        orderBy: 'startTime',
        maxResults: 20,
      );

      final items = result.items ?? [];
      return items
          .where((e) => e.start?.dateTime != null && e.end?.dateTime != null)
          .map((e) => Event(
                id: e.id ?? e.etag ?? 'gcal_${items.indexOf(e)}',
                userId: account.id,
                title: e.summary ?? 'Untitled',
                startTime: e.start!.dateTime!.toLocal(),
                endTime: e.end!.dateTime!.toLocal(),
                location: e.location,
                description: e.description,
                source: 'google_calendar',
                status: 'approved',
              ))
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<String?> createEvent({
    required GoogleSignInAccount account,
    required String title,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    String? description,
  }) async {
    try {
      final headers = await account.authHeaders;
      final client = _AuthedClient(headers);
      final calApi = gcal.CalendarApi(client);

      final event = gcal.Event()
        ..summary = title
        ..location = location
        ..description = description
        ..start = (gcal.EventDateTime()..dateTime = startTime.toUtc())
        ..end = (gcal.EventDateTime()..dateTime = endTime.toUtc());

      final created = await calApi.events.insert(event, 'primary');
      return created.id;
    } catch (_) {
      return null;
    }
  }
}

class _AuthedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _AuthedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}
