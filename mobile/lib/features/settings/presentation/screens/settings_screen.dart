import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/aria_color_scheme.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../providers/settings_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings', style: AppTextStyles.headlineLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(context, ref),
          const SizedBox(height: 24),
          _buildAppearanceSection(ref),
          _buildSection('Assistant', [
            _buildNavTile(
              context,
              icon: Icons.auto_awesome_outlined,
              title: 'Assistant Name',
              subtitle: settings.assistantName,
              route: '/settings/assistant-name',
            ),
            const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildNavTile(
              context,
              icon: Icons.lock_person_outlined,
              title: 'Permissions',
              subtitle: 'Control what ARIA can access',
              route: '/settings/permissions',
            ),
          ]),
          _buildSection('Notifications', [
            _buildToggleTile(
              icon: Icons.notifications_outlined,
              title: 'Push Notifications',
              subtitle: 'Get alerts for suggestions and reminders',
              value: settings.notificationsEnabled,
              onToggle: notifier.toggleNotifications,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildToggleTile(
              icon: Icons.wb_sunny_outlined,
              title: 'Daily Briefing',
              subtitle: 'Morning summary every day at ${settings.briefingTime}',
              value: settings.dailyBriefingEnabled,
              onToggle: notifier.toggleDailyBriefing,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildToggleTile(
              icon: Icons.do_not_disturb_on_outlined,
              title: 'Focus Mode',
              subtitle: 'Suppress alerts when in meetings',
              value: settings.focusModeEnabled,
              onToggle: notifier.toggleFocusMode,
            ),
          ]),
          _buildSection('Integrations', [
            _buildNavTile(
              context,
              icon: Icons.event_outlined,
              title: 'Calendar Connections',
              subtitle: '1 connected',
            ),
            const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildNavTile(
              context,
              icon: Icons.chat_outlined,
              title: 'Messaging Apps',
              subtitle: '0 connected',
            ),
            const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildNavTile(
              context,
              icon: Icons.task_outlined,
              title: 'Task Managers',
              subtitle: '0 connected',
            ),
          ]),
          _buildSection('Data & Privacy', [
            _buildNavTile(
              context,
              icon: Icons.download_outlined,
              title: 'Export My Data',
              subtitle: 'Download all your ARIA data',
            ),
            const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildNavTile(
              context,
              icon: Icons.delete_outline,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account',
              isDestructive: true,
            ),
          ]),
          const SizedBox(height: 16),
          _buildSignOutButton(context, ref),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'ARIA v1.0.0 • Made with ♥',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('V', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vidhi', style: AppTextStyles.headlineSmall),
                const Text('vidhi@mantratec.com', style: AppTextStyles.caption),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Pro',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.textTertiary, size: 20),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildNavTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? route,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: () => route != null ? context.push(route) : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: isDestructive ? AppColors.error : AppColors.textSecondary, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDestructive ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.accent,
            activeTrackColor: AppColors.accent.withOpacity(0.3),
            inactiveThumbColor: AppColors.textTertiary,
            inactiveTrackColor: AppColors.border,
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(WidgetRef ref) {
    final currentIndex = ref.watch(themeIndexProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            'APPEARANCE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        SizedBox(
          height: 88,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: AriaColorScheme.presets.length,
            itemBuilder: (_, i) {
              final scheme = AriaColorScheme.presets[i];
              final isSelected = i == currentIndex;
              return GestureDetector(
                onTap: () => ref.read(themeIndexProvider.notifier).setTheme(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 72,
                  margin: EdgeInsets.only(right: 12, left: i == 0 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? scheme.accent : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: scheme.accent.withOpacity(0.4), blurRadius: 12)]
                        : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: -8,
                        right: -8,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: scheme.accentGradient,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(scheme.emoji, style: const TextStyle(fontSize: 18)),
                          const SizedBox(height: 2),
                          Text(
                            scheme.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                      if (isSelected)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(color: scheme.accent, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSignOutButton(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(authProvider.notifier).signOut();
        context.go('/login');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: const Center(
          child: Text(
            'Sign Out',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
