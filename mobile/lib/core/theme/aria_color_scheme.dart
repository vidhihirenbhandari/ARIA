import 'package:flutter/material.dart';

class AriaColorScheme {
  final int id;
  final String name;
  final String emoji;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color cardBackground;
  final Color accent;
  final Color accentSecondary;

  const AriaColorScheme({
    required this.id,
    required this.name,
    required this.emoji,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.cardBackground,
    required this.accent,
    required this.accentSecondary,
  });

  LinearGradient get accentGradient => LinearGradient(
        colors: [accent, accentSecondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get backgroundGradient => LinearGradient(
        colors: [background, surface],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );

  LinearGradient get cardGradient => LinearGradient(
        colors: [surface, cardBackground],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get userBubbleGradient => LinearGradient(
        colors: [accent, accentSecondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const List<AriaColorScheme> presets = [
    // 0 — Editorial: near-black on warm cream (default)
    AriaColorScheme(
      id: 0,
      name: 'Editorial',
      emoji: '✦',
      background: Color(0xFFF5F1EA),
      surface: Color(0xFFEDE9E1),
      surfaceElevated: Color(0xFFE6E1D8),
      cardBackground: Color(0xFFEDE9E1),
      accent: Color(0xFF1A1410),
      accentSecondary: Color(0xFF3D2B1F),
    ),
    // 1 — Ivory: charcoal on pure white
    AriaColorScheme(
      id: 1,
      name: 'Ivory',
      emoji: '◻',
      background: Color(0xFFFAFAF8),
      surface: Color(0xFFF2F2EF),
      surfaceElevated: Color(0xFFEAEAE6),
      cardBackground: Color(0xFFF2F2EF),
      accent: Color(0xFF2C2C2C),
      accentSecondary: Color(0xFF525252),
    ),
    // 2 — Parchment: dark brown on warm yellow-cream
    AriaColorScheme(
      id: 2,
      name: 'Parchment',
      emoji: '📜',
      background: Color(0xFFF7F0DC),
      surface: Color(0xFFEFE5CC),
      surfaceElevated: Color(0xFFE6DAC0),
      cardBackground: Color(0xFFEFE5CC),
      accent: Color(0xFF3B2410),
      accentSecondary: Color(0xFF6B4020),
    ),
    // 3 — Blush: deep rose on pale pink-cream
    AriaColorScheme(
      id: 3,
      name: 'Blush',
      emoji: '🌸',
      background: Color(0xFFFAF0EF),
      surface: Color(0xFFF2E4E2),
      surfaceElevated: Color(0xFFEAD8D5),
      cardBackground: Color(0xFFF2E4E2),
      accent: Color(0xFF6B2030),
      accentSecondary: Color(0xFF9B3A4C),
    ),
    // 4 — Sage: forest green on pale green-cream
    AriaColorScheme(
      id: 4,
      name: 'Sage',
      emoji: '🌿',
      background: Color(0xFFF0F4EF),
      surface: Color(0xFFE4EDE2),
      surfaceElevated: Color(0xFFD8E5D5),
      cardBackground: Color(0xFFE4EDE2),
      accent: Color(0xFF1E4A30),
      accentSecondary: Color(0xFF3A7055),
    ),
    // 5 — Slate: navy on pale blue-grey
    AriaColorScheme(
      id: 5,
      name: 'Slate',
      emoji: '🩶',
      background: Color(0xFFF0F2F5),
      surface: Color(0xFFE4E8EE),
      surfaceElevated: Color(0xFFD8DDE6),
      cardBackground: Color(0xFFE4E8EE),
      accent: Color(0xFF1A2A3D),
      accentSecondary: Color(0xFF2E4A6B),
    ),
  ];
}
