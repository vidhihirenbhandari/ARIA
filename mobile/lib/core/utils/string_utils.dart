class AriaStringUtils {
  AriaStringUtils._();

  static String capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  static String titleCase(String s) {
    return s.split(' ').map(capitalize).join(' ');
  }

  static String truncate(String s, int maxLength, {String ellipsis = '...'}) {
    if (s.length <= maxLength) return s;
    return '${s.substring(0, maxLength - ellipsis.length)}$ellipsis';
  }

  static String initials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  static String formatConfidence(double confidence) {
    return '${(confidence * 100).round()}%';
  }

  static String pluralize(int count, String singular, {String? plural}) {
    if (count == 1) return '$count $singular';
    return '$count ${plural ?? '${singular}s'}';
  }

  static String removeSpecialChars(String s) {
    return s.replaceAll(RegExp(r'[^\w\s]'), '');
  }

  static String getGreetingMessage(String assistantName) {
    return 'Hi! I\'m $assistantName, your AI assistant. How can I help you today?';
  }

  static String obfuscateEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final username = parts[0];
    final obfuscated = username.length <= 2
        ? '*' * username.length
        : '${username[0]}${'*' * (username.length - 2)}${username[username.length - 1]}';
    return '$obfuscated@${parts[1]}';
  }
}
