import 'package:flutter/material.dart';
import '../theme/aria_color_scheme.dart';

class AppColors {
  AppColors._();

  // Backgrounds — mutable so applyScheme() can update them
  static Color background = const Color(0xFF0D0D15);
  static Color surface = const Color(0xFF131320);
  static Color surfaceElevated = const Color(0xFF1A1A2C);
  static Color cardBackground = const Color(0xFF161624);

  // Accents — mutable (gold + mauve default)
  static Color accent = const Color(0xFFD4A84B);
  static Color accentDark = const Color(0xFF9E7A30);
  static Color accentLight = const Color(0xFFE8C97A);
  static Color secondary = const Color(0xFFB998D8);
  static Color secondaryDark = const Color(0xFF8B6AAF);
  static Color secondaryLight = const Color(0xFFD4B8EC);

  // Status — constant
  static const Color success = Color(0xFF52B788);
  static const Color successLight = Color(0xFFD8F3DC);
  static const Color error = Color(0xFFE55555);
  static const Color errorLight = Color(0xFFFFE0E0);
  static const Color warning = Color(0xFFE8A832);
  static const Color warningLight = Color(0xFFFFF0CC);

  // Text — constant (warm cream palette)
  static const Color textPrimary = Color(0xFFF0ECE0);
  static const Color textSecondary = Color(0xFF9A9590);
  static const Color textTertiary = Color(0xFF5E5A55);
  static const Color textDisabled = Color(0xFF3D3A38);

  // Borders — constant
  static const Color border = Color(0xFF252540);
  static const Color borderLight = Color(0xFF2E2E4A);

  // Gradients — mutable
  static LinearGradient accentGradient = const LinearGradient(
    colors: [Color(0xFFD4A84B), Color(0xFFB998D8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient backgroundGradient = const LinearGradient(
    colors: [Color(0xFF0D0D15), Color(0xFF131320)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient cardGradient = const LinearGradient(
    colors: [Color(0xFF161624), Color(0xFF0D0D15)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient userBubbleGradient = const LinearGradient(
    colors: [Color(0xFFD4A84B), Color(0xFF9E7A30)],
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
