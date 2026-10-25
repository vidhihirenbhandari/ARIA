import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/aria_event.dart';
import '../demo/demo_data.dart';

class CalendarEventsNotifier extends StateNotifier<List<Event>> {
  CalendarEventsNotifier() : super(DemoData.calendarEvents);

  void addEvent(Event event) {
    // Avoid duplicates by id
    final exists = state.any((e) => e.id == event.id);
    if (!exists) state = [...state, event];
  }

  void removeEvent(String id) {
    state = state.where((e) => e.id != id).toList();
  }

  // Replace all Google Calendar-sourced events with a fresh fetch result.
  // Manually added events (source != 'google_calendar') are preserved.
  void syncFromGoogle(List<Event> googleEvents) {
    final local = state.where((e) => e.source != 'google_calendar').toList();
    state = [...googleEvents, ...local];
  }

  // Called on Google sign-out — restores demo data for google-sourced slots.
  void clearGoogleEvents() {
    final local = state.where((e) => e.source != 'google_calendar').toList();
    state = [...DemoData.calendarEvents, ...local];
  }
}

final calendarEventsProvider =
    StateNotifierProvider<CalendarEventsNotifier, List<Event>>(
  (ref) => CalendarEventsNotifier(),
);
