import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class DailyBriefingCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A3E), Color(0xFF0F1728)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.1),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(assistantName, style: AppTextStyles.headlineSmall),
                  Text(
                    'Daily Briefing',
                    style: AppTextStyles.caption.copyWith(color: AppColors.accent),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(greeting, style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(
            summary,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildStat(Icons.videocam_outlined, '$meetingsCount', 'Meetings', AppColors.accent),
              const SizedBox(width: 12),
              _buildStat(Icons.task_alt_outlined, '$tasksCount', 'Tasks', AppColors.secondary),
              const SizedBox(width: 12),
              _buildStat(Icons.notifications_outlined, '$pendingCount', 'Pending', AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.headlineMedium.copyWith(color: color),
            ),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
