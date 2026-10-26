import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/habit.dart';
import '../../../../shared/providers/habits_provider.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final today = _todayStr();
    final doneCount = habits.where((h) => h.completedDates.contains(today)).length;
    final total = habits.length;
    final allDone = total > 0 && doneCount == total;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Habits', style: AppTextStyles.headlineLarge),
        centerTitle: false,
      ),
      body: habits.isEmpty
          ? _buildEmpty(context, ref)
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _SummaryHeader(doneCount: doneCount, total: total, allDone: allDone),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _HabitCard(habit: habits[i]),
                    childCount: habits.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () => _showAddSheet(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌱', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 20),
            Text('Build your habits', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 10),
            Text(
              'Track anything that matters to you — no defaults, just yours.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => _showAddSheet(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Text(
                  'Add your first habit',
                  style: AppTextStyles.button.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddHabitSheet(ref: ref),
    );
  }
}

// ── Summary header ──────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final int doneCount;
  final int total;
  final bool allDone;

  const _SummaryHeader({
    required this.doneCount,
    required this.total,
    required this.allDone,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : doneCount / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
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
                Expanded(
                  child: Text(
                    allDone
                        ? 'All habits done! Amazing work today 🎉'
                        : '$doneCount/$total habits done today',
                    style: AppTextStyles.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.border,
                color: allDone ? AppColors.success : AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Habit card ──────────────────────────────────────────────────────────────

class _HabitCard extends ConsumerWidget {
  final Habit habit;

  const _HabitCard({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(habit.color);
    final streak = habit.currentStreak();
    final completedToday = habit.isCompletedToday();

    return GestureDetector(
      onLongPress: () => _confirmDelete(context, ref),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: completedToday ? color.withOpacity(0.5) : AppColors.border,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Emoji
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(habit.emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + streak
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(habit.name, style: AppTextStyles.labelLarge),
                        const SizedBox(height: 2),
                        Text(
                          streak > 0 ? '🔥 $streak day streak' : 'Start your streak!',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                  // Toggle button
                  GestureDetector(
                    onTap: () => ref.read(habitsProvider.notifier).toggleToday(habit.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: completedToday ? color : Colors.transparent,
                        border: Border.all(
                          color: completedToday ? color : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: completedToday
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 7-day mini grid
              _SevenDayGrid(habit: habit, color: color),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete habit?', style: AppTextStyles.headlineSmall),
        content: Text(
          'Remove "${habit.name}" and all its history?',
          style: AppTextStyles.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(habitsProvider.notifier).deleteHabit(habit.id);
              Navigator.pop(ctx);
            },
            child: Text('Delete', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ── 7-day completion grid ───────────────────────────────────────────────────

class _SevenDayGrid extends StatelessWidget {
  final Habit habit;
  final Color color;

  const _SevenDayGrid({required this.habit, required this.color});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = now.subtract(Duration(days: 6 - i));
        final key =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final done = habit.completedDates.contains(key);
        final isToday = i == 6;
        return Column(
          children: [
            Text(
              _shortDay(day.weekday),
              style: AppTextStyles.labelSmall.copyWith(
                color: isToday ? AppColors.textSecondary : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? color : AppColors.border,
                border: isToday
                    ? Border.all(color: color.withOpacity(0.6), width: 1.5)
                    : null,
              ),
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
            ),
          ],
        );
      }),
    );
  }

  String _shortDay(int wd) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[(wd - 1) % 7];
  }
}

// ── Add Habit bottom sheet ──────────────────────────────────────────────────

class _AddHabitSheet extends StatefulWidget {
  final WidgetRef ref;
  const _AddHabitSheet({required this.ref});

  @override
  State<_AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<_AddHabitSheet> {
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController(text: '✅');
  String _selectedFrequency = 'daily';
  int _selectedColor = 0xFF3A7BD5;

  static const _colors = [
    0xFF3A7BD5,
    0xFF10B981,
    0xFF8B5CF6,
    0xFFEC4899,
    0xFFEF4444,
    0xFFE8803A,
    0xFF4F46E5,
    0xFF6B7280,
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final emoji = _emojiCtrl.text.trim().isEmpty ? '✅' : _emojiCtrl.text.trim();

    final rand = Random();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final id = '${ts}_${rand.nextInt(99999).toString().padLeft(5, '0')}';

    final habit = Habit(
      id: id,
      name: name,
      emoji: emoji,
      frequency: _selectedFrequency,
      targetCount: 1,
      completedDates: [],
      color: _selectedColor,
      createdAt: DateTime.now(),
    );

    widget.ref.read(habitsProvider.notifier).addHabit(habit);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('New Habit', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 16),

          // Name + Emoji row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji input
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _emojiCtrl,
                  autofocus: false,
                  maxLength: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '✅',
                    hintStyle: const TextStyle(fontSize: 24),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name field
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Habit name',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Color picker
          Text('Color', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: _colors.map((c) {
              final selected = c == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: AppColors.textPrimary, width: 2.5)
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 15)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Frequency chips
          Text('Frequency', style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: ['daily', 'weekly'].map((f) {
              final selected = _selectedFrequency == f;
              return GestureDetector(
                onTap: () => setState(() => _selectedFrequency = f),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accent : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? AppColors.accent : AppColors.border,
                    ),
                  ),
                  child: Text(
                    f[0].toUpperCase() + f.substring(1),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _save,
              child: const Text('Add Habit', style: AppTextStyles.button),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

String _todayStr() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}
