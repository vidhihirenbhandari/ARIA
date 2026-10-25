import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_auth_service.dart';
import '../services/google_calendar_service.dart';
import 'calendar_events_provider.dart';

// ── Auth state ─────────────────────────────────────────────────────────────

class GoogleAuthNotifier extends StateNotifier<GoogleSignInAccount?> {
  final GoogleAuthService _service;
  final Ref _ref;

  GoogleAuthNotifier(this._service, this._ref) : super(null) {
    _tryRestoreSession();
  }

  Future<void> _tryRestoreSession() async {
    final account = await _service.signInSilently();
    if (account != null) {
      state = account;
      await _syncCalendar(account);
    }
  }

  Future<bool> signIn() async {
    final account = await _service.signIn();
    if (account != null) {
      state = account;
      await _syncCalendar(account);
      return true;
    }
    return false;
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = null;
    _ref.read(calendarEventsProvider.notifier).clearGoogleEvents();
  }

  Future<void> refreshCalendar() async {
    final account = state;
    if (account != null) await _syncCalendar(account);
  }

  Future<void> _syncCalendar(GoogleSignInAccount account) async {
    final events = await GoogleCalendarService().fetchTodayEvents(account);
    _ref.read(calendarEventsProvider.notifier).syncFromGoogle(events);
  }
}

final googleAuthProvider =
    StateNotifierProvider<GoogleAuthNotifier, GoogleSignInAccount?>((ref) {
  return GoogleAuthNotifier(GoogleAuthService(), ref);
});
