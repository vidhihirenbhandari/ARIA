import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/aria_color_scheme.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../../shared/services/local_storage.dart';
import '../../../../shared/services/profile_service.dart';
import '../../../../shared/services/proactive_notification_service.dart';
import '../providers/settings_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _waterRemindersEnabled = false;
  bool _exerciseReminderEnabled = false;
  final _apiKeyController = TextEditingController();
  bool _apiKeyObscured = true;

  @override
  void initState() {
    super.initState();
    final storage = ref.read(localStorageProvider);
    final existingKey = storage.getApiKey() ?? '';
    _apiKeyController.text = existingKey;
    _waterRemindersEnabled =
        storage.get('water_reminders_enabled') as bool? ?? false;
    _exerciseReminderEnabled =
        storage.get('exercise_reminder_enabled') as bool? ?? false;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey(String key) async {
    final storage = ref.read(localStorageProvider);
    await storage.saveApiKey(key.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('API key saved'),
          backgroundColor: AppColors.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showApiKeyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Anthropic API Key', style: AppTextStyles.headlineSmall),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your Anthropic API key to enable real AI responses. '
              'Get one at console.anthropic.com',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              obscureText: _apiKeyObscured,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'sk-ant-...',
                hintStyle:
                    const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.accent, width: 2),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _apiKeyObscured ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _apiKeyObscured = !_apiKeyObscured),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveApiKey(_apiKeyController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: AppTextStyles.button),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    final profile = ref.read(userProfileProvider);
    final nameCtrl = TextEditingController(text: profile.fullName);
    final workplaceCtrl = TextEditingController(text: profile.workplace);
    final roleCtrl = TextEditingController(text: profile.role);
    final goalsCtrl = TextEditingController(text: profile.goals);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Profile', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 4),
            const Text(
              'Help ARIA understand you better for personalized responses.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),
            _profileField(nameCtrl, 'Full Name', Icons.person_outline),
            const SizedBox(height: 12),
            _profileField(workplaceCtrl, 'Workplace', Icons.business_outlined),
            const SizedBox(height: 12),
            _profileField(roleCtrl, 'Your Role / Title', Icons.work_outline),
            const SizedBox(height: 12),
            _profileField(goalsCtrl, 'Current Goals', Icons.flag_outlined,
                maxLines: 2),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final svc = ref.read(profileServiceProvider);
                  final updated = profile.copyWith(
                    fullName: nameCtrl.text.trim(),
                    workplace: workplaceCtrl.text.trim(),
                    role: roleCtrl.text.trim(),
                    goals: goalsCtrl.text.trim(),
                  );
                  await svc.saveProfile(updated);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Profile saved'),
                        backgroundColor: AppColors.accent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Profile', style: AppTextStyles.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textTertiary,
        ),
        prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.accent, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final storage = ref.read(localStorageProvider);
    final hasApiKey =
        (storage.getApiKey() ?? '').isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textSecondary),
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

          // ── ARIA Intelligence ──────────────────────────────────────
          _buildSection('ARIA Intelligence', [
            _buildNavTile(
              context,
              icon: Icons.vpn_key_outlined,
              title: 'Anthropic API Key',
              subtitle: hasApiKey
                  ? 'Connected — real AI responses enabled'
                  : 'Not set — using demo mode',
              onTap: _showApiKeyDialog,
              trailingWidget: hasApiKey
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4CAF50),
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ]),

          // ── Profile ────────────────────────────────────────────────
          _buildSection('Profile', [
            _buildNavTile(
              context,
              icon: Icons.person_outlined,
              title: 'Your Details',
              subtitle: 'Name, workplace, role, and goals',
              onTap: _showProfileDialog,
            ),
            const Divider(
                height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildNavTile(
              context,
              icon: Icons.auto_awesome_outlined,
              title: 'Assistant Name',
              subtitle: settings.assistantName,
              route: '/settings/assistant-name',
            ),
            const Divider(
                height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildNavTile(
              context,
              icon: Icons.lock_person_outlined,
              title: 'Permissions',
              subtitle: 'Control what ARIA can access',
              route: '/settings/permissions',
            ),
          ]),

          // ── Health & Wellness ──────────────────────────────────────
          _buildSection('Health & Wellness', [
            _buildToggleTile(
              icon: Icons.water_drop_outlined,
              title: 'Water Reminders',
              subtitle: 'Remind me to drink water every 2 hours',
              value: _waterRemindersEnabled,
              onToggle: () async {
                setState(
                    () => _waterRemindersEnabled = !_waterRemindersEnabled);
                await storage.put(
                    'water_reminders_enabled', _waterRemindersEnabled);
                final svc = ref.read(proactiveNotificationServiceProvider);
                await svc.scheduleWaterReminders(
                    enabled: _waterRemindersEnabled);
              },
            ),
            const Divider(
                height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildToggleTile(
              icon: Icons.directions_run_outlined,
              title: 'Exercise Reminder',
              subtitle: 'Daily movement reminder at 6:00 PM',
              value: _exerciseReminderEnabled,
              onToggle: () async {
                setState(() =>
                    _exerciseReminderEnabled = !_exerciseReminderEnabled);
                await storage.put(
                    'exercise_reminder_enabled', _exerciseReminderEnabled);
                final svc = ref.read(proactiveNotificationServiceProvider);
                await svc.scheduleExerciseReminder(
                    enabled: _exerciseReminderEnabled);
              },
            ),
          ]),

          // ── Notifications ──────────────────────────────────────────
          _buildSection('Notifications', [
            _buildToggleTile(
              icon: Icons.notifications_outlined,
              title: 'Push Notifications',
              subtitle: 'Get alerts for suggestions and reminders',
              value: settings.notificationsEnabled,
              onToggle: notifier.toggleNotifications,
            ),
            const Divider(
                height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildToggleTile(
              icon: Icons.wb_sunny_outlined,
              title: 'Daily Briefing',
              subtitle:
                  'Morning summary every day at ${settings.briefingTime}',
              value: settings.dailyBriefingEnabled,
              onToggle: notifier.toggleDailyBriefing,
            ),
            const Divider(
                height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildToggleTile(
              icon: Icons.do_not_disturb_on_outlined,
              title: 'Focus Mode',
              subtitle: 'Suppress alerts when in meetings',
              value: settings.focusModeEnabled,
              onToggle: notifier.toggleFocusMode,
            ),
          ]),

          // ── Integrations ───────────────────────────────────────────
          _buildSection('Integrations', [
            _buildNavTile(
              context,
              icon: Icons.event_outlined,
              title: 'Calendar Connections',
              subtitle: '1 connected',
            ),
            const Divider(
                height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildNavTile(
              context,
              icon: Icons.chat_outlined,
              title: 'Messaging Apps',
              subtitle: '0 connected',
            ),
            const Divider(
                height: 1, indent: 16, endIndent: 16, color: AppColors.border),
            _buildNavTile(
              context,
              icon: Icons.task_outlined,
              title: 'Task Managers',
              subtitle: '0 connected',
            ),
          ]),

          // ── Data & Privacy ─────────────────────────────────────────
          _buildSection('Data & Privacy', [
            _buildNavTile(
              context,
              icon: Icons.download_outlined,
              title: 'Export My Data',
              subtitle: 'Download all your ARIA data',
            ),
            const Divider(
                height: 1, indent: 16, endIndent: 16, color: AppColors.border),
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
              'ARIA v1.0.0 • Made with love',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textTertiary),
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
              child: Text('V',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Pro',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.textTertiary, size: 20),
            onPressed: _showProfileDialog,
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
    VoidCallback? onTap,
    bool isDestructive = false,
    Widget? trailingWidget,
  }) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap();
        } else if (route != null) {
          context.push(route);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                color:
                    isDestructive ? AppColors.error : AppColors.textSecondary,
                size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color:
                          isDestructive ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (trailingWidget != null) ...[
              trailingWidget,
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 20),
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
                onTap: () =>
                    ref.read(themeIndexProvider.notifier).setTheme(i),
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
                        ? [
                            BoxShadow(
                                color: scheme.accent.withOpacity(0.4),
                                blurRadius: 12)
                          ]
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
                          Text(scheme.emoji,
                              style: const TextStyle(fontSize: 18)),
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
                            decoration: BoxDecoration(
                                color: scheme.accent, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 12),
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
