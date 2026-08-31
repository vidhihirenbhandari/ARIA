import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/aria_task.dart';

class TaskCard extends StatelessWidget {
  final AriaTask task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
  });

  Color get _priorityColor {
    switch (task.priority) {
      case 'high':
        return AppColors.error;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'completed';

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error.withOpacity(0.15),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDone ? AppColors.border : _priorityColor.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggle,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDone ? AppColors.success : Colors.transparent,
                  border: Border.all(
                    color: isDone ? AppColors.success : AppColors.borderLight,
                    width: 2,
                  ),
                ),
                child: isDone
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? AppColors.textTertiary : AppColors.textPrimary,
                    ),
                  ),
                  if (task.dueDate != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.schedule_outlined, size: 12, color: _dueDateColor),
                        const SizedBox(width: 4),
                        Text(
                          _formatDue(task.dueDate!),
                          style: AppTextStyles.caption.copyWith(color: _dueDateColor),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _priorityColor,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _dueDateColor {
    if (task.dueDate == null) return AppColors.textTertiary;
    final diff = task.dueDate!.difference(DateTime.now()).inDays;
    if (diff < 0) return AppColors.error;
    if (diff <= 2) return AppColors.warning;
    return AppColors.textTertiary;
  }

  String _formatDue(DateTime dt) {
    final diff = dt.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Overdue';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    return 'Due in $diff days';
  }
}
