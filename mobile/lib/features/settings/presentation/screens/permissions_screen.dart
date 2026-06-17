import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/settings_provider.dart';

class PermissionsScreen extends ConsumerWidget {
  const PermissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perms = ref.watch(permissionsProvider);
    final notifier = ref.read(permissionsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Permissions', style: AppTextStyles.headlineLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Calendar & Events', [
            _PermissionItem(
              itemKey: 'calendar',
              icon: Icons.calendar_today_outlined,
              title: 'Calendar Access',
              subtitle: 'Read and create calendar events',
              value: perms.calendarAccess,
              onToggle: () => notifier.toggle('calendar'),
            ),
          ]),
          _buildSection('Communications', [
            _PermissionItem(
              itemKey: 'whatsapp',
              icon: Icons.chat_outlined,
              title: 'WhatsApp Analysis',
              subtitle: 'Detect meeting plans from messages',
              value: perms.whatsappAccess,
              onToggle: () => notifier.toggle('whatsapp'),
            ),
            _PermissionItem(
              itemKey: 'email',
              icon: Icons.email_outlined,
              title: 'Email Analysis',
              subtitle: 'Detect travel bookings and meetings',
              value: perms.emailAccess,
              onToggle: () => notifier.toggle('email'),
            ),
            _PermissionItem(
              itemKey: 'sms',
              icon: Icons.sms_outlined,
              title: 'SMS Access',
              subtitle: 'Read OTPs and booking confirmations',
              value: perms.smsAccess,
              onToggle: () => notifier.toggle('sms'),
            ),
          ]),
          _buildSection('Device', [
            _PermissionItem(
              itemKey: 'callLog',
              icon: Icons.call_outlined,
              title: 'Call Log Access',
              subtitle: 'Remember people you frequently call',
              value: perms.callLogAccess,
              onToggle: () => notifier.toggle('callLog'),
            ),
            _PermissionItem(
              itemKey: 'location',
              icon: Icons.location_on_outlined,
              title: 'Location Access',
              subtitle: 'Traffic alerts and location-based reminders',
              value: perms.locationAccess,
              onToggle: () => notifier.toggle('location'),
            ),
          ]),
          _buildSection('AI & Memory', [
            _PermissionItem(
              itemKey: 'memory',
              icon: Icons.psychology_outlined,
              title: 'Memory Storage',
              subtitle: 'Remember commitments and important conversations',
              value: perms.memoryStorage,
              onToggle: () => notifier.toggle('memory'),
            ),
            _PermissionItem(
              itemKey: 'travel',
              icon: Icons.flight_outlined,
              title: 'Travel Detection',
              subtitle: 'Auto-detect travel bookings from email',
              value: perms.travelDetection,
              onToggle: () => notifier.toggle('travel'),
            ),
          ]),
          const SizedBox(height: 16),
          _buildThresholdSection(perms, notifier),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
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
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast)
                    const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: AppColors.border,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildThresholdSection(PermissionsState perms, PermissionsNotifier notifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            'SUGGESTION SENSITIVITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Confidence Threshold', style: AppTextStyles.bodyMedium),
                  Text(
                    '${(perms.suggestionThreshold * 100).round()}%',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Only show suggestions with confidence above this level',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: AppColors.border,
                  thumbColor: AppColors.accent,
                  overlayColor: Color(0x1A4A9EFF),
                ),
                child: Slider(
                  value: perms.suggestionThreshold,
                  min: 0.5,
                  max: 0.95,
                  divisions: 9,
                  onChanged: notifier.setThreshold,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('More suggestions', style: AppTextStyles.caption),
                  Text('Fewer, higher quality', style: AppTextStyles.caption),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final String itemKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final VoidCallback onToggle;

  const _PermissionItem({
    required this.itemKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: value ? AppColors.accent : AppColors.textTertiary, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
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
}
