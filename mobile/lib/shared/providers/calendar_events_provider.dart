import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/aria_event.dart';
import '../demo/demo_data.dart';

class CalendarEventsNotifier extends StateNotifier<List<Event>> {
  CalendarEventsNotifier() : super(DemoData.calendarEvents);

  void addEvent(Event event) {
    state = [...state, event];
  }

  void removeEvent(String id) {
    state = state.where((e) => e.id != id).toList();
  }
}

final calendarEventsProvider =
    StateNotifierProvider<CalendarEventsNotifier, List<Event>>(
  (ref) => CalendarEventsNotifier(),
);
