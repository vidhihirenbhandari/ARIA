import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/providers/commitments_provider.dart';
import '../../../../shared/providers/people_provider.dart';
import '../../../../shared/services/local_storage.dart';

class WeeklyReviewScreen extends ConsumerWidget {
  const WeeklyReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commitments = ref.watch(commitmentsProvider);
    final people = ref.watch(peopleProvider);
    final storage = ref.read(localStorageProvider);

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final nextWeek = now.add(const Duration(days: 7));

    // ── Commitments this week ────────────────────────────────────────────────
    final weekCommitments = commitments.where((c) {
      final createdRecently = c.createdAt.isAfter(weekAgo);
      final dueThisWeek = c.dueDate != null &&
          c.dueDate!.isAfter(weekAgo) &&
          c.dueDate!.isBefore(now.add(const Duration(days: 1)));
      return createdRecently || dueThisWeek;
    }).toList();
    final completedCount = weekCommitments.where((c) => c.isCompleted).length;

    // ── People contacted this week ───────────────────────────────────────────
    final contactedPeople = people
        .where((p) => p.lastContact != null && p.lastContact!.isAfter(weekAgo))
        .toList();

    // ── Habits ───────────────────────────────────────────────────────────────
    final habitsList = storage.getList('habits_list');

    // ── Focus sessions this week ─────────────────────────────────────────────
    final focusSessions = storage.getList('focus_sessions');
    int weeklyFocusMinutes = 0;
    for (final s in focusSessions) {
      final dateStr = s['date'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.tryParse(dateStr);
      if (date != null && date.isAfter(weekAgo)) {
        weeklyFocusMinutes += (s['durationMinutes'] as num?)?.toInt() ?? 0;
      }
    }

    // ── Upcoming & follow-ups ────────────────────────────────────────────────
    final upcoming = commitments
        .where((c) =>
            !c.isCompleted &&
            c.dueDate != null &&
            c.dueDate!.isAfter(now) &&
            c.dueDate!.isBefore(nextWeek))
        .toList();

    final followUps = people
        .where((p) =>
            p.followUpDate != null && p.followUpDate!.isBefore(nextWeek))
        .toList();

    // ── Share text builder ───────────────────────────────────────────────────
    String buildShareText() {
      final buf = StringBuffer();
      buf.writeln('Weekly Review — ${_fmtDate(weekAgo)} to ${_fmtDate(now)}');
      buf.writeln();
      buf.writeln('Commitments: $completedCount/${weekCommitments.length} completed');
      if (contactedPeople.isNotEmpty) {
        buf.writeln('People: ${contactedPeople.map((p) => p.name).join(', ')}');
      }
      buf.writeln('Focus time: ${_fmtFocus(weeklyFocusMinutes)}');
      if (upcoming.isNotEmpty) {
        buf.writeln();
        buf.writeln('Upcoming next week:');
        for (final c in upcoming) {
          buf.writeln('  • ${c.text} (${c.person})');
        }
      }
      if (followUps.isNotEmpty) {
        buf.writeln();
        buf.writeln('Follow-ups needed:');
        for (final p in followUps) {
          buf.writeln(
              '  • ${p.name}${p.followUpNote != null ? ': ${p.followUpNote}' : ''}');
        }
      }
      return buf.toString();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Weekly Review', style: AppTextStyles.headlineMedium),
        centerTitle: false,
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: buildShareText()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Summary copied to clipboard',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.white),
                    ),
                    backgroundColor: AppColors.accent,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            icon: Icon(Icons.copy_outlined, size: 16, color: AppColors.accent),
            label: Text(
              'Share',
              style: AppTextStyles.labelLarge.copyWith(color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${_fmtDate(weekAgo)} – ${_fmtDate(now)}',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 20),
          // ── Commitments ──────────────────────────────────────────────────
          _ReviewCard(
            icon: Icons.task_alt_outlined,
            title: 'Commitments',
            child: weekCommitments.isEmpty
                ? Text('No commitments tracked this week.',
                    style: AppTextStyles.bodySmall)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StatRow(
                        label: 'Completed',
                        value: '$completedCount / ${weekCommitments.length}',
                        color: completedCount == weekCommitments.length &&
                                weekCommitments.isNotEmpty
                            ? AppColors.success
                            : AppColors.accent,
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: weekCommitments.isEmpty
                              ? 0
                              : completedCount / weekCommitments.length,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation(
                            completedCount == weekCommitments.length &&
                                    weekCommitments.isNotEmpty
                                ? AppColors.success
                                : AppColors.accent,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          // ── People ───────────────────────────────────────────────────────
          _ReviewCard(
            icon: Icons.people_outline_rounded,
            title: 'People',
            child: contactedPeople.isEmpty
                ? Text('No contacts this week.',
                    style: AppTextStyles.bodySmall)
                : Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: contactedPeople
                        .map((p) => _PersonChip(name: p.name))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),
          // ── Habits ───────────────────────────────────────────────────────
          _ReviewCard(
            icon: Icons.loop_rounded,
            title: 'Habits',
            child: habitsList.isEmpty
                ? Text('No habits tracked yet.',
                    style: AppTextStyles.bodySmall)
                : Column(
                    children: habitsList.map((h) {
                      final name = h['name'] as String? ?? 'Habit';
                      final datesRaw =
                          h['completedDates'] as List<dynamic>? ?? [];
                      final completedThisWeek = datesRaw
                          .whereType<String>()
                          .map((d) => DateTime.tryParse(d))
                          .whereType<DateTime>()
                          .where((d) => d.isAfter(weekAgo))
                          .length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _StatRow(
                          label: name,
                          value: '$completedThisWeek / 7 days',
                          color: completedThisWeek >= 5
                              ? AppColors.success
                              : AppColors.accent,
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 12),
          // ── Focus ────────────────────────────────────────────────────────
          _ReviewCard(
            icon: Icons.timer_outlined,
            title: 'Focus Time',
            child: _StatRow(
              label: 'Total this week',
              value: _fmtFocus(weeklyFocusMinutes),
              color: weeklyFocusMinutes >= 60
                  ? AppColors.success
                  : AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          // ── Next week ────────────────────────────────────────────────────
          _ReviewCard(
            icon: Icons.calendar_today_outlined,
            title: 'Next Week',
            child: (upcoming.isEmpty && followUps.isEmpty)
                ? Text('Looking clear ahead!',
                    style: AppTextStyles.bodySmall)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        Text(
                          'Upcoming commitments',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        ...upcoming.map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(
                                        top: 5, right: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '${c.text} — ${c.person}',
                                      style: AppTextStyles.bodySmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (c.dueDate != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      _fmtDate(c.dueDate!),
                                      style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textTertiary),
                                    ),
                                  ],
                                ],
                              ),
                            )),
                      ],
                      if (followUps.isNotEmpty) ...[
                        if (upcoming.isNotEmpty) const SizedBox(height: 12),
                        Text(
                          'Follow-ups needed',
                          style: AppTextStyles.labelLarge
                              .copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        ...followUps.map((p) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(
                                        top: 5, right: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      p.followUpNote != null
                                          ? '${p.name}: ${p.followUpNote}'
                                          : p.name,
                                      style: AppTextStyles.bodySmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  static String _fmtFocus(int minutes) {
    if (minutes == 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

// ── Review card ──────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _ReviewCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: AppColors.accent, size: 17),
              ),
              const SizedBox(width: 10),
              Text(title, style: AppTextStyles.headlineSmall),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Stat row ─────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style:
              AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        Text(value, style: AppTextStyles.labelLarge.copyWith(color: color)),
      ],
    );
  }
}

// ── Person chip ───────────────────────────────────────────────────────────────

class _PersonChip extends StatelessWidget {
  final String name;

  const _PersonChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Text(
        name,
        style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent),
      ),
    );
  }
}
