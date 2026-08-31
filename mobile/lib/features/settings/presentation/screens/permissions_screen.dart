import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/settings_provider.dart';

class _AppInfo {
  final String name;
  final String urlScheme;
  final IconData icon;
  final Color color;

  const _AppInfo({
    required this.name,
    required this.urlScheme,
    required this.icon,
    required this.color,
  });
}

final _connectedApps = <_AppInfo>[
  _AppInfo(
    name: 'WhatsApp',
    urlScheme: 'whatsapp://',
    icon: Icons.chat_rounded,
    color: const Color(0xFF25D366),
  ),
  _AppInfo(
    name: 'Gmail',
    urlScheme: 'googlegmail://',
    icon: Icons.email_rounded,
    color: const Color(0xFFEA4335),
  ),
  _AppInfo(
    name: 'Slack',
    urlScheme: 'slack://',
    icon: Icons.hub_rounded,
    color: const Color(0xFF4A154B),
  ),
  _AppInfo(
    name: 'Google Calendar',
    urlScheme: 'googlecalendar://',
    icon: Icons.calendar_month_rounded,
    color: const Color(0xFF4285F4),
  ),
  _AppInfo(
    name: 'Maps',
    urlScheme: 'googlemaps://',
    icon: Icons.map_rounded,
    color: const Color(0xFF34A853),
  ),
];

class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  final Map<String, bool> _installedApps = {};
  bool _loadingApps = true;

  @override
  void initState() {
    super.initState();
    _detectInstalledApps();
  }

  Future<void> _detectInstalledApps() async {
    if (kIsWeb) {
      setState(() => _loadingApps = false);
      return;
    }
    for (final app in _connectedApps) {
      try {
        final uri = Uri.parse(app.urlScheme);
        final canOpen = await canLaunchUrl(uri);
        _installedApps[app.name] = canOpen;
      } catch (_) {
        _installedApps[app.name] = false;
      }
    }
    if (mounted) setState(() => _loadingApps = false);
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionsProvider);
    final notifier = ref.read(permissionsProvider.notifier);

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
        title: const Text('Permissions', style: AppTextStyles.headlineLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connected Apps section
          _buildSectionHeader('Connected Apps'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: _loadingApps
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _connectedApps
                        .map((app) => _buildAppChip(app))
                        .toList(),
                  ),
          ),

          // Device Permissions
          _buildSection('Device Permissions', [
            _PermissionItem(
              itemKey: 'contacts',
              icon: Icons.contacts_outlined,
              title: 'Contacts',
              subtitle: 'Access your contacts for context-aware responses',
              explanation:
                  'ARIA uses contact names to personalize reminders and suggestions.',
              value: perms.calendarAccess,
              onToggle: () => notifier.toggle('calendar'),
            ),
            _PermissionItem(
              itemKey: 'calendar',
              icon: Icons.calendar_today_outlined,
              title: 'Calendar Access',
              subtitle: 'Read and create calendar events',
              explanation:
                  'Required for scheduling reminders and reading your schedule.',
              value: perms.calendarAccess,
              onToggle: () => notifier.toggle('calendar'),
            ),
            _PermissionItem(
              itemKey: 'microphone',
              icon: Icons.mic_outlined,
              title: 'Microphone',
              subtitle: 'Voice input for hands-free interactions',
              explanation:
                  'Used only when you tap the microphone button — never recorded in the background.',
              value: perms.memoryStorage,
              onToggle: () => notifier.toggle('memory'),
            ),
            _PermissionItem(
              itemKey: 'notifications',
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'Receive proactive reminders and briefings',
              explanation:
                  'Allows ARIA to send you timely reminders, daily briefings, and smart suggestions.',
              value: perms.travelDetection,
              onToggle: () => notifier.toggle('travel'),
            ),
            _PermissionItem(
              itemKey: 'location',
              icon: Icons.location_on_outlined,
              title: 'Location Access',
              subtitle: 'Traffic alerts and location-based reminders',
              explanation:
                  'Used for commute predictions and location-triggered reminders. Never shared.',
              value: perms.locationAccess,
              onToggle: () => notifier.toggle('location'),
            ),
          ]),

          _buildSection('Communications', [
            _PermissionItem(
              itemKey: 'whatsapp',
              icon: Icons.chat_outlined,
              title: 'WhatsApp Analysis',
              subtitle: 'Detect meeting plans from messages',
              explanation:
                  'ARIA reads relevant conversations to find commitments and meeting suggestions.',
              value: perms.whatsappAccess,
              onToggle: () => notifier.toggle('whatsapp'),
            ),
            _PermissionItem(
              itemKey: 'email',
              icon: Icons.email_outlined,
              title: 'Email Analysis',
              subtitle: 'Detect travel bookings and meetings',
              explanation:
                  'Scans email subjects and senders — full message content is never stored.',
              value: perms.emailAccess,
              onToggle: () => notifier.toggle('email'),
            ),
            _PermissionItem(
              itemKey: 'sms',
              icon: Icons.sms_outlined,
              title: 'SMS Access',
              subtitle: 'Read OTPs and booking confirmations',
              explanation:
                  'Only reads transactional messages; personal SMS are never accessed.',
              value: perms.smsAccess,
              onToggle: () => notifier.toggle('sms'),
            ),
          ]),

          _buildSection('AI & Memory', [
            _PermissionItem(
              itemKey: 'memory',
              icon: Icons.psychology_outlined,
              title: 'Memory Storage',
              subtitle: 'Remember commitments and important conversations',
              explanation:
                  'Stored locally on your device. You can view and delete memories anytime.',
              value: perms.memoryStorage,
              onToggle: () => notifier.toggle('memory'),
            ),
            _PermissionItem(
              itemKey: 'travel',
              icon: Icons.flight_outlined,
              title: 'Travel Detection',
              subtitle: 'Auto-detect travel bookings from email',
              explanation:
                  'Recognises flight/hotel confirmation emails to add trips to your timeline.',
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

  Widget _buildAppChip(_AppInfo app) {
    final isInstalled = _installedApps[app.name] ?? false;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isInstalled
            ? app.color.withOpacity(0.15)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isInstalled ? app.color.withOpacity(0.4) : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            app.icon,
            color: isInstalled ? app.color : AppColors.textTertiary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            app.name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color:
                  isInstalled ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
          if (!kIsWeb) ...[
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isInstalled
                    ? const Color(0xFF4CAF50)
                    : AppColors.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
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
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
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

  Widget _buildThresholdSection(
      PermissionsState perms, PermissionsNotifier notifier) {
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
                  const Text('Confidence Threshold',
                      style: AppTextStyles.bodyMedium),
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
              const Text(
                'Only show suggestions with confidence above this level',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 12),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: AppColors.border,
                  thumbColor: AppColors.accent,
                  overlayColor: const Color(0x1A4A9EFF),
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

class _PermissionItem extends StatefulWidget {
  final String itemKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final String explanation;
  final bool value;
  final VoidCallback onToggle;

  const _PermissionItem({
    required this.itemKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.explanation,
    required this.value,
    required this.onToggle,
  });

  @override
  State<_PermissionItem> createState() => _PermissionItemState();
}

class _PermissionItemState extends State<_PermissionItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                widget.icon,
                color: widget.value ? AppColors.accent : AppColors.textTertiary,
                size: 22,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: AppTextStyles.bodyMedium),
                    const SizedBox(height: 2),
                    Text(widget.subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Icon(
                  _expanded ? Icons.info : Icons.info_outline,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: widget.value,
                onChanged: (_) => widget.onToggle(),
                activeColor: AppColors.accent,
                activeTrackColor: AppColors.accent.withOpacity(0.3),
                inactiveThumbColor: AppColors.textTertiary,
                inactiveTrackColor: AppColors.border,
              ),
            ],
          ),
        ),
        if (_expanded)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withOpacity(0.2)),
            ),
            child: Text(
              widget.explanation,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}
