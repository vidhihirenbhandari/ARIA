import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/aria_color_scheme.dart';
import 'core/constants/app_colors.dart';
import 'shared/providers/theme_provider.dart';

class AriaApp extends ConsumerWidget {
  const AriaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeIndex = ref.watch(themeIndexProvider);
    final scheme = AriaColorScheme.presets[themeIndex];

    // Update static AppColors so all existing widgets pick up the new palette
    AppColors.applyScheme(scheme);

    final router = ref.watch(routerProvider);

    // ValueKey forces a full widget tree rebuild when the theme changes,
    // ensuring every widget re-reads the updated AppColors statics.
    return KeyedSubtree(
      key: ValueKey(themeIndex),
      child: MaterialApp.router(
        title: 'ARIA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        routerConfig: router,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.noScaling,
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
