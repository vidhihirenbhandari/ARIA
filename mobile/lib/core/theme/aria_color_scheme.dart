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
    AriaColorScheme(
      id: 0,
      name: 'Cosmic',
      emoji: '🌌',
      background: Color(0xFF0D0D1A),
      surface: Color(0xFF1A1A2E),
      surfaceElevated: Color(0xFF16213E),
      cardBackground: Color(0xFF0F172A),
      accent: Color(0xFF4A9EFF),
      accentSecondary: Color(0xFF8B5CF6),
    ),
    AriaColorScheme(
      id: 1,
      name: 'Aurora',
      emoji: '🌠',
      background: Color(0xFF0F0D1A),
      surface: Color(0xFF1E1A2E),
      surfaceElevated: Color(0xFF1A1535),
      cardBackground: Color(0xFF120F22),
      accent: Color(0xFF7C3AED),
      accentSecondary: Color(0xFFEC4899),
    ),
    AriaColorScheme(
      id: 2,
      name: 'Emerald',
      emoji: '🌿',
      background: Color(0xFF0D1A14),
      surface: Color(0xFF1A2E20),
      surfaceElevated: Color(0xFF152618),
      cardBackground: Color(0xFF0F1E14),
      accent: Color(0xFF10B981),
      accentSecondary: Color(0xFF06B6D4),
    ),
    AriaColorScheme(
      id: 3,
      name: 'Sunset',
      emoji: '🌅',
      background: Color(0xFF1A0D0F),
      surface: Color(0xFF2E1A1C),
      surfaceElevated: Color(0xFF261518),
      cardBackground: Color(0xFF1E0F11),
      accent: Color(0xFFF97316),
      accentSecondary: Color(0xFFF43F5E),
    ),
    AriaColorScheme(
      id: 4,
      name: 'Gold',
      emoji: '✨',
      background: Color(0xFF1A160D),
      surface: Color(0xFF2E271A),
      surfaceElevated: Color(0xFF261E15),
      cardBackground: Color(0xFF1E180F),
      accent: Color(0xFFF59E0B),
      accentSecondary: Color(0xFFEF4444),
    ),
    AriaColorScheme(
      id: 5,
      name: 'Indigo',
      emoji: '💜',
      background: Color(0xFF0D0F1A),
      surface: Color(0xFF1A1C2E),
      surfaceElevated: Color(0xFF151835),
      cardBackground: Color(0xFF0F1122),
      accent: Color(0xFF6366F1),
      accentSecondary: Color(0xFF22D3EE),
    ),
  ];
}
