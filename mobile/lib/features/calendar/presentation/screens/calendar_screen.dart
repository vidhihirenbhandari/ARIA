import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/aria_color_scheme.dart';
import '../../../../shared/models/aria_event.dart';
import '../../../../shared/providers/calendar_events_provider.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../widgets/event_detection_card.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final allEvents = ref.watch(calendarEventsProvider);
    final approvedEvents = allEvents.where((e) => e.status == 'approved').toList();

    final selectedDayEvents = approvedEvents.where((e) {
      return e.startTime.year == _selectedDate.year &&
          e.startTime.month == _selectedDate.month &&
          e.startTime.day == _selectedDate.day;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final eventDays = <DateTime>{};
    for (final e in approvedEvents) {
      eventDays.add(DateTime(e.startTime.year, e.startTime.month, e.startTime.day));
    }

    final themeIndex = ref.watch(themeIndexProvider);
    final scheme = AriaColorScheme.presets[themeIndex.clamp(0, AriaColorScheme.presets.length - 1)];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Calendar', style: AppTextStyles.headlineLarge),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: AppColors.accent),
            onPressed: _showAddEventSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildMonthCalendar(eventDays, scheme),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _buildDaySchedule(selectedDayEvents),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCalendar(Set<DateTime> eventDays, AriaColorScheme scheme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    // Monday = 0 offset
    final startOffset = (firstDay.weekday - 1) % 7;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        // Month navigation header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                onPressed: () => setState(() {
                  _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
                }),
              ),
              Expanded(
                child: Text(
                  _monthLabel(_viewMonth),
                  style: AppTextStyles.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                onPressed: () => setState(() {
                  _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
                }),
              ),
            ],
          ),
        ),
        // Weekday labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: _weekdays
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        // Calendar grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: List.generate(rows, (row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: List.generate(7, (col) {
                    final cellIndex = row * 7 + col;
                    final dayNum = cellIndex - startOffset + 1;
                    if (dayNum < 1 || dayNum > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 44));
                    }
                    final cellDate = DateTime(_viewMonth.year, _viewMonth.month, dayNum);
                    final isToday = cellDate == today;
                    final isSelected = cellDate.year == _selectedDate.year &&
                        cellDate.month == _selectedDate.month &&
                        cellDate.day == _selectedDate.day;
                    final hasEvents = eventDays.contains(cellDate);

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDate = cellDate),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [scheme.accent, scheme.accentSecondary],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : null,
                            color: isSelected ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isToday && !isSelected
                                ? Border.all(color: scheme.accent.withOpacity(0.6), width: 1.5)
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isSelected
                                      ? Colors.white
                                      : isToday
                                          ? scheme.accent
                                          : AppColors.textPrimary,
                                  fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                                ),
                              ),
                              if (hasEvents)
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(top: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withOpacity(0.8)
                                        : scheme.accent,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              else
                                const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDaySchedule(List<Event> events) {
    final label = _dayLabel(_selectedDate);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        Row(
          children: [
            Text(label, style: AppTextStyles.headlineSmall),
            const Spacer(),
            if (events.isNotEmpty)
              Text(
                '${events.length} event${events.length == 1 ? '' : 's'}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (events.isEmpty)
          _buildEmptyDay()
        else
          ...events.map((e) => _buildEventTile(e)),
      ],
    );
  }

  Widget _buildEmptyDay() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined, color: AppColors.textTertiary, size: 36),
          const SizedBox(height: 12),
          Text(
            'Nothing scheduled',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap + to add an event',
            style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(Event event) {
    final isPast = event.endTime.isBefore(DateTime.now());
    final isNow = DateTime.now().isAfter(event.startTime) &&
        DateTime.now().isBefore(event.endTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isNow ? AppColors.accent.withOpacity(0.07) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNow ? AppColors.accent.withOpacity(0.35) : AppColors.border,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: isNow
                    ? AppColors.accent
                    : isPast
                        ? AppColors.border
                        : AppColors.secondary,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fmtTime(event.startTime),
                    style: AppTextStyles.caption.copyWith(
                      color: isNow ? AppColors.accent : AppColors.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _fmtTime(event.endTime),
                    style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isPast && !isNow
                                  ? AppColors.textTertiary
                                  : AppColors.textPrimary,
                              decoration: isPast && !isNow ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (isNow)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Now',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (event.location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: AppColors.textTertiary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.location!,
                              style: AppTextStyles.caption,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (event.description != null && event.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        event.description!,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final selected = DateTime(d.year, d.month, d.day);
    if (selected == today) return 'Today';
    if (selected == tomorrow) return 'Tomorrow';
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'PM' : 'AM'}';
  }

  void _showAddEventSheet() {
    final titleController = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add to ${_dayLabel(_selectedDate)}', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Event title',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    final start = _selectedDate.copyWith(hour: 9, minute: 0, second: 0);
                    final end = _selectedDate.copyWith(hour: 10, minute: 0, second: 0);
                    ref.read(calendarEventsProvider.notifier).addEvent(Event(
                      id: 'manual-${DateTime.now().millisecondsSinceEpoch}',
                      userId: 'demo-user',
                      title: title,
                      startTime: start,
                      endTime: end,
                      source: 'manual',
                      status: 'approved',
                    ));
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Add Event', style: AppTextStyles.button),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
