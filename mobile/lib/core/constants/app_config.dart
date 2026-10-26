class AppConfig {
  AppConfig._();

  // ── Google OAuth ────────────────────────────────────────────────────────────
  // 1. Go to console.cloud.google.com → Create Project → Enable Calendar API
  // 2. Credentials → Create OAuth 2.0 Client ID
  //    • Web: set Authorized JS origin to https://vidhihirenbhandari.github.io
  //    • iOS: download GoogleService-Info.plist → ios/Runner/
  // 3. Paste the Web client ID below and in web/index.html
  static const String googleWebClientId =
      'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  // Calendar scopes requested
  static const List<String> googleCalendarScopes = [
    'https://www.googleapis.com/auth/calendar.readonly',
    'https://www.googleapis.com/auth/calendar.events',
  ];
}
