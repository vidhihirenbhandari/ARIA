import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/aria_event.dart';
import '../../../../shared/providers/calendar_events_provider.dart';
import '../../../../shared/providers/departure_settings_provider.dart';

class DepartureAlertCard extends ConsumerWidget {
  const DepartureAlertCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(calendarEventsProvider);
    final settings = ref.watch(departureSettingsProvider);
    final notifier = ref.read(departureSettingsProvider.notifier);

    final now = DateTime.now();
    final upcoming = events
        .where((e) =>
            e.startTime.isAfter(now) &&
            e.startTime.isBefore(now.add(const Duration(hours: 4))))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (upcoming.isEmpty) return const SizedBox.shrink();

    final next = upcoming.first;
    final commuteMinutes = notifier.commuteForEvent(next.id);
    final leaveBy = next.startTime.subtract(Duration(minutes: commuteMinutes));
    final minutesUntilLeave = leaveBy.difference(now).inMinutes;

    final isLate = minutesUntilLeave < 0;
    final isUrgent = minutesUntilLeave >= 0 && minutesUntilLeave <= 10;

    final cardColor = isLate
        ? AppColors.error.withOpacity(0.12)
        : isUrgent
            ? const Color(0xFFB8860B).withOpacity(0.12)
            : AppColors.surface;

    final accentColor = isLate
        ? AppColors.error
        : isUrgent
            ? const Color(0xFFB8860B)
            : AppColors.accent;

    final leaveLabel = _formatTime(leaveBy);
    final statusText = isLate
        ? 'You should have left already'
        : isUrgent
            ? 'Leave in $minutesUntilLeave min'
            : 'Leave by $leaveLabel';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showCommuteSheet(context, next, commuteMinutes, notifier),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isLate ? Icons.warning_rounded : Icons.directions_walk_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        next.title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (next.location != null && next.location!.isNotEmpty)
                        Text(
                          next.location!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.accent.withOpacity(0.55),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(next.startTime),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.accent.withOpacity(0.6),
                      ),
                    ),
                    Text(
                      '${commuteMinutes}m commute',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.accent.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = h >= 12 ? 'PM' : 'AM';
    final hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour:$m $period';
  }

  void _showCommuteSheet(
    BuildContext context,
    Event event,
    int currentMinutes,
    DepartureSettingsNotifier notifier,
  ) {
    int selected = currentMinutes;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Commute to "${event.title}"',
                  style: AppTextStyles.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'How long does it take to get there?',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.accent.withOpacity(0.6)),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final mins in [10, 15, 20, 30, 45, 60])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('${mins}m'),
                        selected: selected == mins,
                        onSelected: (_) => setState(() => selected = mins),
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(
                          color: selected == mins
                              ? AppColors.background
                              : AppColors.accent,
                          fontWeight: FontWeight.w500,
                        ),
                        backgroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    notifier.setEventCommute(event.id, selected);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
