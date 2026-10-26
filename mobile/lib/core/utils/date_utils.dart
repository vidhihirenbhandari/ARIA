import 'package:intl/intl.dart';

class AriaDateUtils {
  AriaDateUtils._();

  static String formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  static String formatDate(DateTime dateTime) {
    return DateFormat('MMM d, yyyy').format(dateTime);
  }

  static String formatDateShort(DateTime dateTime) {
    return DateFormat('MMM d').format(dateTime);
  }

  static String formatDayOfWeek(DateTime dateTime) {
    return DateFormat('EEEE').format(dateTime);
  }

  static String formatRelativeDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff > 1 && diff < 7) return DateFormat('EEEE').format(dateTime);
    if (diff < 0 && diff > -7) return '${-diff} days ago';
    return formatDateShort(dateTime);
  }

  static String formatEventTime(DateTime start, DateTime end) {
    return '${formatTime(start)} – ${formatTime(end)}';
  }

  static String formatFullDateTime(DateTime dateTime) {
    return DateFormat('EEE, MMM d • h:mm a').format(dateTime);
  }

  static String formatGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime date) => isSameDay(date, DateTime.now());

  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return isSameDay(date, tomorrow);
  }

  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return formatDateShort(dateTime);
  }

  static List<DateTime> getWeekDays(DateTime referenceDate) {
    final monday = referenceDate.subtract(
      Duration(days: referenceDate.weekday - 1),
    );
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }
}
