class AppConstants {
  AppConstants._();

  // API
  static const String baseUrl = 'https://api.aria-assistant.ai/v1';
  static const String wsBaseUrl = 'wss://ws.aria-assistant.ai/v1';
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const int maxRetries = 3;

  // Storage keys
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'user_data';
  static const String onboardingKey = 'onboarding_complete';
  static const String settingsKey = 'app_settings';
  static const String assistantNameKey = 'assistant_name';
  static const String themeKey = 'app_theme';

  // Assistant
  static const List<String> defaultAssistantNames = ['ARIA', 'Nova', 'Atlas'];
  static const String defaultAssistantName = 'ARIA';

  // Chat
  static const int maxMessageLength = 4000;
  static const Duration typingIndicatorDelay = Duration(milliseconds: 500);
  static const Duration streamingCharDelay = Duration(milliseconds: 20);

  // Animation durations
  static const Duration shortAnimation = Duration(milliseconds: 150);
  static const Duration mediumAnimation = Duration(milliseconds: 300);
  static const Duration longAnimation = Duration(milliseconds: 500);
  static const Duration pageTransition = Duration(milliseconds: 350);

  // Pagination
  static const int defaultPageSize = 20;

  // Voice
  static const Duration maxRecordingDuration = Duration(seconds: 60);
  static const double voiceActivationThreshold = 0.3;

  // Notification channels
  static const String defaultChannelId = 'aria_default';
  static const String defaultChannelName = 'ARIA Notifications';
  static const String urgentChannelId = 'aria_urgent';
  static const String urgentChannelName = 'ARIA Urgent';

  // Calendar sources
  static const List<String> calendarSources = ['Google', 'Apple', 'Outlook'];

  // Communication sources
  static const List<String> commSources = ['WhatsApp', 'Email', 'Slack'];
}
