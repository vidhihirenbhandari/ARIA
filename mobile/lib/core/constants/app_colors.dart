import 'package:flutter/material.dart';
import '../theme/aria_color_scheme.dart';

class AppColors {
  AppColors._();

  // Backgrounds — mutable so applyScheme() can update them
  static Color background = const Color(0xFF0D0D1A);
  static Color surface = const Color(0xFF1A1A2E);
  static Color surfaceElevated = const Color(0xFF16213E);
  static Color cardBackground = const Color(0xFF0F172A);

  // Accents — mutable
  static Color accent = const Color(0xFF4A9EFF);
  static Color accentDark = const Color(0xFF2563EB);
  static Color accentLight = const Color(0xFF93C5FD);
  static Color secondary = const Color(0xFF8B5CF6);
  static Color secondaryDark = const Color(0xFF6D28D9);
  static Color secondaryLight = const Color(0xFFC4B5FD);

  // Status — constant, never changes with theme
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);

  // Text — constant
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF475569);
  static const Color textDisabled = Color(0xFF334155);

  // Borders — constant
  static const Color border = Color(0xFF1E293B);
  static const Color borderLight = Color(0xFF334155);

  // Gradients — mutable
  static LinearGradient accentGradient = const LinearGradient(
    colors: [Color(0xFF4A9EFF), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient backgroundGradient = const LinearGradient(
    colors: [Color(0xFF0D0D1A), Color(0xFF1A1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient cardGradient = const LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient userBubbleGradient = const LinearGradient(
    colors: [Color(0xFF4A9EFF), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static void applyScheme(AriaColorScheme scheme) {
    background = scheme.background;
    surface = scheme.surface;
    surfaceElevated = scheme.surfaceElevated;
    cardBackground = scheme.cardBackground;
    accent = scheme.accent;
    secondary = scheme.accentSecondary;
    accentGradient = scheme.accentGradient;
    backgroundGradient = scheme.backgroundGradient;
    cardGradient = scheme.cardGradient;
    userBubbleGradient = scheme.userBubbleGradient;
    // derived shades
    accentDark = Color.lerp(scheme.accent, Colors.black, 0.25)!;
    accentLight = Color.lerp(scheme.accent, Colors.white, 0.4)!;
    secondaryDark = Color.lerp(scheme.accentSecondary, Colors.black, 0.25)!;
    secondaryLight = Color.lerp(scheme.accentSecondary, Colors.white, 0.4)!;
  }
}
