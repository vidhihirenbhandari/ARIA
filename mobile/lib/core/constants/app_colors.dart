import 'package:flutter/material.dart';
import '../theme/aria_color_scheme.dart';

class AppColors {
  AppColors._();

  // Backgrounds — mutable so applyScheme() can update them
  static Color background = const Color(0xFFF5F1EA);
  static Color surface = const Color(0xFFEDE9E1);
  static Color surfaceElevated = const Color(0xFFE6E1D8);
  static Color cardBackground = const Color(0xFFEDE9E1);

  // Accents — mutable (editorial black + caramel default)
  static Color accent = const Color(0xFF1A1410);
  static Color accentDark = const Color(0xFF0D0A06);
  static Color accentLight = const Color(0xFF3D3530);
  static Color secondary = const Color(0xFF8B7355);
  static Color secondaryDark = const Color(0xFF5C4A30);
  static Color secondaryLight = const Color(0xFFB8966A);

  // Status — constant
  static const Color success = Color(0xFF3A7D52);
  static const Color successLight = Color(0xFFD8F0E2);
  static const Color error = Color(0xFFC0392B);
  static const Color errorLight = Color(0xFFFFE0DC);
  static const Color warning = Color(0xFFB8860B);
  static const Color warningLight = Color(0xFFFFF3CC);

  // Text — constant (warm dark palette)
  static const Color textPrimary = Color(0xFF1A1410);
  static const Color textSecondary = Color(0xFF6B6057);
  static const Color textTertiary = Color(0xFFA89D92);
  static const Color textDisabled = Color(0xFFD4CFC8);

  // Borders — constant
  static const Color border = Color(0xFFD8D2C8);
  static const Color borderLight = Color(0xFFE6E1D8);

  // Gradients — mutable
  static LinearGradient accentGradient = const LinearGradient(
    colors: [Color(0xFF1A1410), Color(0xFF3D2B1F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient backgroundGradient = const LinearGradient(
    colors: [Color(0xFFF5F1EA), Color(0xFFEDE9E1)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient cardGradient = const LinearGradient(
    colors: [Color(0xFFEDE9E1), Color(0xFFE6E1D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient userBubbleGradient = const LinearGradient(
    colors: [Color(0xFF1A1410), Color(0xFF3D2B1F)],
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
    accentDark = Color.lerp(scheme.accent, Colors.black, 0.3)!;
    accentLight = Color.lerp(scheme.accent, Colors.white, 0.4)!;
    secondaryDark = Color.lerp(scheme.accentSecondary, Colors.black, 0.3)!;
    secondaryLight = Color.lerp(scheme.accentSecondary, Colors.white, 0.4)!;
  }
}
