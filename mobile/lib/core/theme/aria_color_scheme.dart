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
    // 0 — Prestige: gold + mauve on deep dark navy (default)
    AriaColorScheme(
      id: 0,
      name: 'Prestige',
      emoji: '✦',
      background: Color(0xFF0D0D15),
      surface: Color(0xFF131320),
      surfaceElevated: Color(0xFF1A1A2C),
      cardBackground: Color(0xFF161624),
      accent: Color(0xFFD4A84B),
      accentSecondary: Color(0xFFB998D8),
    ),
    // 1 — Aurora: violet + rose on deep purple-dark
    AriaColorScheme(
      id: 1,
      name: 'Aurora',
      emoji: '🌠',
      background: Color(0xFF0F0D1A),
      surface: Color(0xFF1C1A2E),
      surfaceElevated: Color(0xFF221E38),
      cardBackground: Color(0xFF141224),
      accent: Color(0xFF9B72CF),
      accentSecondary: Color(0xFFEC6FAD),
    ),
    // 2 — Emerald: teal + cyan on dark forest
    AriaColorScheme(
      id: 2,
      name: 'Emerald',
      emoji: '🌿',
      background: Color(0xFF0A1410),
      surface: Color(0xFF111E18),
      surfaceElevated: Color(0xFF172820),
      cardBackground: Color(0xFF0E1A14),
      accent: Color(0xFF2EC4A0),
      accentSecondary: Color(0xFF38BDF8),
    ),
    // 3 — Sunset: coral + amber on dark warm
    AriaColorScheme(
      id: 3,
      name: 'Sunset',
      emoji: '🌅',
      background: Color(0xFF150D0A),
      surface: Color(0xFF201510),
      surfaceElevated: Color(0xFF2A1C15),
      cardBackground: Color(0xFF1A1008),
      accent: Color(0xFFE8844A),
      accentSecondary: Color(0xFFE8B84A),
    ),
    // 4 — Arctic: steel blue + indigo on navy
    AriaColorScheme(
      id: 4,
      name: 'Arctic',
      emoji: '❄️',
      background: Color(0xFF0A0E1A),
      surface: Color(0xFF111828),
      surfaceElevated: Color(0xFF162030),
      cardBackground: Color(0xFF0E1422),
      accent: Color(0xFF4A9EFF),
      accentSecondary: Color(0xFF818CF8),
    ),
    // 5 — Onyx: silver + rose gold on pure black
    AriaColorScheme(
      id: 5,
      name: 'Onyx',
      emoji: '🖤',
      background: Color(0xFF0A0A0A),
      surface: Color(0xFF141414),
      surfaceElevated: Color(0xFF1C1C1C),
      cardBackground: Color(0xFF111111),
      accent: Color(0xFFC8A882),
      accentSecondary: Color(0xFFD4708A),
    ),
  ];
}
