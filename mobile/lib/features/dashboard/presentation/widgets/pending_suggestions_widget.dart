import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class PendingSuggestionsWidget extends StatelessWidget {
  final List<Map<String, dynamic>> suggestions;
  final Function(Map<String, dynamic>) onApprove;
  final Function(Map<String, dynamic>) onIgnore;

  const PendingSuggestionsWidget({
    super.key,
    required this.suggestions,
    required this.onApprove,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.warning.withOpacity(0.5), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Needs Your Approval',
                style: AppTextStyles.headlineSmall,
              ),
              const Spacer(),
              Text(
                '${suggestions.length} items',
                style: AppTextStyles.caption.copyWith(color: AppColors.warning),
              ),
            ],
          ),
        ),
        ...suggestions.map((s) => _buildSuggestionTile(s)),
      ],
    );
  }

  Widget _buildSuggestionTile(Map<String, dynamic> suggestion) {
    final confidence = suggestion['confidence'] as double;
    final type = suggestion['type'] as String? ?? 'event';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _typeIcon(type),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  suggestion['title'] as String,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              _confidenceBadge(confidence),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            suggestion['description'] as String? ?? '',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onIgnore(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: const Center(
                      child: Text('Ignore',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: () => onApprove(suggestion),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('Approve',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          )),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'meeting':
        icon = Icons.people_outline;
        color = AppColors.accent;
        break;
      case 'travel':
        icon = Icons.flight_outlined;
        color = AppColors.secondary;
        break;
      case 'task':
        icon = Icons.task_outlined;
        color = AppColors.success;
        break;
      default:
        icon = Icons.calendar_today_outlined;
        color = AppColors.warning;
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  Widget _confidenceBadge(double confidence) {
    final color = confidence >= 0.85
        ? AppColors.success
        : confidence >= 0.65
            ? AppColors.warning
            : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '${(confidence * 100).round()}%',
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
