import '../models/aria_event.dart';
import '../models/aria_travel.dart';
import '../../features/dashboard/data/briefing_repository.dart';

class DemoData {
  DemoData._();

  static DailyBriefing get briefing {
    final hour = DateTime.now().hour;
    final greet = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return DailyBriefing(
      greeting: greet,
      summary:
          'You have 3 meetings today: Team Standup at 10 AM, Client Call with Raj at 2 PM, '
          'and Product Review at 4:30 PM. 2 tasks are due today. '
          'Your IndiGo flight to Mumbai is tomorrow at 7:00 AM.',
      meetingsCount: 3,
      tasksCount: 2,
      pendingCount: 1,
    );
  }

  static List<Event> get pendingEvents => [
        Event(
          id: 'demo-event-1',
          userId: 'demo-user',
          title: 'Meeting with Raj Sharma',
          startTime: DateTime.now().add(const Duration(days: 1)).copyWith(hour: 15, minute: 0),
          endTime: DateTime.now().add(const Duration(days: 1)).copyWith(hour: 16, minute: 0),
          source: 'WhatsApp',
          status: 'pending',
          confidenceScore: 0.92,
          description: '"Let\'s meet tomorrow at 3 PM" — Raj Sharma',
          location: 'Google Meet',
        ),
      ];

  static List<Event> get calendarEvents {
    final now = DateTime.now();
    DateTime d(int offset, int h, int m) =>
        DateTime(now.year, now.month, now.day + offset, h, m);
    return [
      // Today
      Event(
        id: 'cal-1',
        userId: 'demo-user',
        title: 'Team Standup',
        startTime: d(0, 10, 0),
        endTime: d(0, 10, 30),
        source: 'google_calendar',
        status: 'approved',
      ),
      Event(
        id: 'cal-2',
        userId: 'demo-user',
        title: 'Client Call — Raj Sharma',
        startTime: d(0, 14, 0),
        endTime: d(0, 15, 0),
        location: 'Google Meet',
        source: 'google_calendar',
        status: 'approved',
      ),
      Event(
        id: 'cal-3',
        userId: 'demo-user',
        title: 'Product Review',
        startTime: d(0, 16, 30),
        endTime: d(0, 17, 30),
        source: 'google_calendar',
        status: 'approved',
      ),
      // Tomorrow
      Event(
        id: 'cal-4',
        userId: 'demo-user',
        title: 'IndiGo Flight 6E-204 — DEL → BOM',
        startTime: d(1, 7, 0),
        endTime: d(1, 9, 15),
        location: 'Delhi Airport, T2',
        source: 'google_calendar',
        status: 'approved',
      ),
      Event(
        id: 'cal-5',
        userId: 'demo-user',
        title: 'Mumbai Office Check-in',
        startTime: d(1, 11, 0),
        endTime: d(1, 12, 0),
        location: 'BKC, Mumbai',
        source: 'google_calendar',
        status: 'approved',
      ),
      // Day +2
      Event(
        id: 'cal-6',
        userId: 'demo-user',
        title: 'Investor Pitch Prep',
        startTime: d(2, 9, 0),
        endTime: d(2, 11, 0),
        description: 'Finalize deck and run through Q&A',
        source: 'manual',
        status: 'approved',
      ),
      Event(
        id: 'cal-7',
        userId: 'demo-user',
        title: 'Lunch — Ananya',
        startTime: d(2, 13, 0),
        endTime: d(2, 14, 0),
        location: 'Trident, Nariman Point',
        source: 'manual',
        status: 'approved',
      ),
      // Day +4
      Event(
        id: 'cal-8',
        userId: 'demo-user',
        title: 'Q4 Planning Workshop',
        startTime: d(4, 10, 0),
        endTime: d(4, 17, 0),
        location: 'Conference Room B',
        source: 'google_calendar',
        status: 'approved',
      ),
      // Day +5
      Event(
        id: 'cal-9',
        userId: 'demo-user',
        title: 'Weekly 1:1 — Priya',
        startTime: d(5, 11, 0),
        endTime: d(5, 11, 30),
        location: 'Google Meet',
        source: 'google_calendar',
        status: 'approved',
      ),
      Event(
        id: 'cal-10',
        userId: 'demo-user',
        title: 'Dentist Appointment',
        startTime: d(5, 18, 0),
        endTime: d(5, 19, 0),
        location: 'Fortis Dental, Bandra',
        source: 'manual',
        status: 'approved',
      ),
      // Day +7
      Event(
        id: 'cal-11',
        userId: 'demo-user',
        title: 'Sprint Retrospective',
        startTime: d(7, 15, 0),
        endTime: d(7, 16, 0),
        location: 'Zoom',
        source: 'google_calendar',
        status: 'approved',
      ),
      // Day +10
      Event(
        id: 'cal-12',
        userId: 'demo-user',
        title: 'Board Presentation',
        startTime: d(10, 14, 0),
        endTime: d(10, 16, 0),
        location: 'HQ Boardroom',
        description: 'Q3 results + Q4 roadmap',
        source: 'google_calendar',
        status: 'approved',
      ),
      // Day +12
      Event(
        id: 'cal-13',
        userId: 'demo-user',
        title: 'Team Offsite — Day 1',
        startTime: d(12, 9, 0),
        endTime: d(12, 18, 0),
        location: 'Lonavala',
        source: 'google_calendar',
        status: 'approved',
      ),
      Event(
        id: 'cal-14',
        userId: 'demo-user',
        title: 'Team Offsite — Day 2',
        startTime: d(13, 9, 0),
        endTime: d(13, 17, 0),
        location: 'Lonavala',
        source: 'google_calendar',
        status: 'approved',
      ),
    ];
  }

  static List<TravelBooking> get travelBookings => [
        TravelBooking(
          id: 'demo-travel-1',
          userId: 'demo-user',
          type: 'flight',
          departureTime:
              DateTime.now().add(const Duration(days: 1)).copyWith(hour: 7, minute: 0),
          arrivalTime:
              DateTime.now().add(const Duration(days: 1)).copyWith(hour: 9, minute: 15),
          status: 'confirmed',
          details: {
            'airline': 'IndiGo',
            'flightNumber': '6E-204',
            'from': 'DEL',
            'to': 'BOM',
            'bookingRef': 'IND7X3',
          },
        ),
      ];

  static String chatResponse(String userMessage) {
    final m = userMessage.toLowerCase();
    if (m.contains('today') || m.contains('schedule') || m.contains('meetings')) {
      return 'Here\'s your day, Vidhi:\n\n'
          '• 10:00 AM — Team Standup (30 min)\n'
          '• 2:00 PM — Client Call with Raj (1 hr) · Google Meet\n'
          '• 4:30 PM — Product Review (1 hr)\n\n'
          'You also have 2 tasks due: "Send proposal to Raj" and "Review Q4 budget". '
          'Would you like me to help you prepare for any of these?';
    }
    if (m.contains('flight') || m.contains('travel') || m.contains('mumbai') || m.contains('del')) {
      return 'Your IndiGo flight 6E-204 departs Delhi (DEL) tomorrow at 7:00 AM and arrives Mumbai (BOM) at 9:15 AM. Booking ref: IND7X3.\n\n'
          'A few things I can help with:\n'
          '• Set a 4:30 AM wake-up alarm\n'
          '• Book an airport cab for Terminal 2\n'
          '• Generate a packing checklist\n\n'
          'Which would you like to do?';
    }
    if (m.contains('raj') || m.contains('meeting')) {
      return 'I detected a meeting with Raj Sharma from WhatsApp — "Let\'s meet tomorrow at 3 PM" with 92% confidence.\n\n'
          'It\'s in your Pending Suggestions waiting for your approval. Want me to add it to your calendar?';
    }
    if (m.contains('remind') || m.contains('reminder')) {
      return 'Got it! I\'ll create a reminder for you. When would you like to be reminded, and what\'s the message?';
    }
    if (m.contains('task') || m.contains('todo')) {
      return 'You have 2 tasks due today:\n\n'
          '• Send proposal to Raj  [HIGH PRIORITY]\n'
          '• Review Q4 budget  [MEDIUM]\n\n'
          'Would you like to mark any as done, or add a new task?';
    }
    if (m.contains('hello') || m.contains('hi') || m.contains('hey')) {
      return 'Hey Vidhi! I\'m ARIA, your personal assistant. I\'ve been keeping track of everything for you.\n\n'
          'You have a busy day — 3 meetings and a flight to Mumbai tomorrow morning. '
          'What would you like help with?';
    }
    if (m.contains('commit') || m.contains('promise') || m.contains('said')) {
      return 'From your recent conversations, I found these commitments:\n\n'
          '• Promised Raj to send the project proposal by end of day\n'
          '• Agreed to review Q4 budget before the Product Review at 4:30 PM\n'
          '• Mentioned to the team you\'d share standup notes\n\n'
          'Want me to add reminders for any of these?';
    }
    return 'I\'m here to help, Vidhi. I can show you your schedule, manage your tasks, '
        'track your travel, and remember important things for you. What do you need?';
  }
}
