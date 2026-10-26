import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/aria_color_scheme.dart';
import '../../../../shared/providers/theme_provider.dart';

class DailyBriefingCard extends ConsumerWidget {
  final String assistantName;
  final String greeting;
  final String summary;
  final int meetingsCount;
  final int tasksCount;
  final int pendingCount;

  const DailyBriefingCard({
    super.key,
    required this.assistantName,
    required this.greeting,
    required this.summary,
    required this.meetingsCount,
    required this.tasksCount,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeIndex = ref.watch(themeIndexProvider);
    final scheme = AriaColorScheme.presets[themeIndex.clamp(0, AriaColorScheme.presets.length - 1)];

    final cardGradient = LinearGradient(
      colors: [scheme.accent, scheme.accentSecondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final borderColor = Colors.white.withOpacity(0.12);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(assistantName,
                  style: AppTextStyles.headlineSmall.copyWith(color: Colors.white)),
              Text(
                'Daily Briefing',
                style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.65)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(greeting,
              style: AppTextStyles.headlineMedium.copyWith(color: Colors.white)),
          const SizedBox(height: 8),
          Text(
            summary,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withOpacity(0.75)),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStat(Icons.videocam_outlined, '$meetingsCount', 'Meetings'),
              const SizedBox(width: 10),
              _buildStat(Icons.task_alt_outlined, '$tasksCount', 'Tasks'),
              const SizedBox(width: 10),
              _buildStat(Icons.notifications_outlined, '$pendingCount', 'Pending'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withOpacity(0.9), size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.headlineMedium.copyWith(color: Colors.white),
            ),
            Text(label,
                style: AppTextStyles.caption.copyWith(color: Colors.white.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }
}
