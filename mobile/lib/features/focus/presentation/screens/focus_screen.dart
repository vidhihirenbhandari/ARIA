import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/services/local_storage.dart';

enum _TimerState { idle, running, paused, complete }

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  static const _durationOptions = [25, 45, 60];
  int _selectedDuration = 25;
  bool _customMode = false;
  final _customController = TextEditingController();
  final _taskController = TextEditingController();

  _TimerState _timerState = _TimerState.idle;
  int _remainingSeconds = 25 * 60;
  int _totalSeconds = 25 * 60;
  Timer? _timer;
  String _todayFocusLabel = '';

  // Smart Focus state
  bool _dndMeetings = false;
  String? _quietStart; // "HH:mm"
  String? _quietEnd;   // "HH:mm"
  List<Map<String, dynamic>> _focusBlocks = [];

  @override
  void initState() {
    super.initState();
    _loadTodayFocus();
    _loadSmartFocusSettings();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _taskController.dispose();
    _customController.dispose();
    super.dispose();
  }

  void _loadTodayFocus() {
    final storage = ref.read(localStorageProvider);
    final sessions = storage.getList('focus_sessions');
    final today = DateTime.now();
    int totalMinutes = 0;
    for (final s in sessions) {
      final dateStr = s['date'] as String?;
      if (dateStr == null) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;
      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        totalMinutes += (s['durationMinutes'] as num?)?.toInt() ?? 0;
      }
    }
    if (mounted) {
      setState(() {
        _todayFocusLabel = _formatMinutes(totalMinutes);
      });
    }
  }

  void _loadSmartFocusSettings() {
    final storage = ref.read(localStorageProvider);
    final dnd = storage.get('focus_dnd_meetings');
    final qs = storage.get('focus_quiet_start') as String?;
    final qe = storage.get('focus_quiet_end') as String?;
    final blocks = storage.getList('focus_blocks');
    if (mounted) {
      setState(() {
        _dndMeetings = dnd == true;
        _quietStart = qs;
        _quietEnd = qe;
        _focusBlocks = blocks.map((b) => Map<String, dynamic>.from(b as Map)).toList();
      });
    }
  }

  Future<void> _saveSmartFocusSettings() async {
    final storage = ref.read(localStorageProvider);
    await storage.put('focus_dnd_meetings', _dndMeetings);
    if (_quietStart != null) await storage.put('focus_quiet_start', _quietStart!);
    if (_quietEnd != null) await storage.put('focus_quiet_end', _quietEnd!);
    await storage.putList('focus_blocks', _focusBlocks);
  }

  String _formatMinutes(int minutes) {
    if (minutes == 0) return '0m focused';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m focused';
    if (m == 0) return '${h}h focused';
    return '${h}h ${m}m focused';
  }

  String _formatTimeOfDay(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _displayTime(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final tod = TimeOfDay(hour: h, minute: m);
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final min = m.toString().padLeft(2, '0');
    return '$hour:$min $period';
  }

  void _setDuration(int minutes) {
    if (_timerState != _TimerState.idle) return;
    setState(() {
      _selectedDuration = minutes;
      _customMode = false;
      _remainingSeconds = minutes * 60;
      _totalSeconds = minutes * 60;
    });
  }

  void _startTimer() {
    if (_timerState == _TimerState.idle || _timerState == _TimerState.paused) {
      setState(() => _timerState = _TimerState.running);
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_remainingSeconds <= 1) {
          _timer?.cancel();
          setState(() {
            _remainingSeconds = 0;
            _timerState = _TimerState.complete;
          });
          _saveSession();
          _loadTodayFocus();
        } else {
          setState(() => _remainingSeconds--);
        }
      });
    }
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _timerState = _TimerState.paused);
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _timerState = _TimerState.idle;
      _remainingSeconds = _selectedDuration * 60;
      _totalSeconds = _selectedDuration * 60;
    });
  }

  Future<void> _saveSession() async {
    final storage = ref.read(localStorageProvider);
    final sessions = storage.getList('focus_sessions');
    final elapsed = _totalSeconds - _remainingSeconds;
    sessions.add({
      'date': DateTime.now().toIso8601String(),
      'durationMinutes': elapsed ~/ 60,
      'task': _taskController.text.trim(),
    });
    await storage.putList('focus_sessions', sessions);
  }

  String get _timeDisplay {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progress {
    if (_totalSeconds == 0) return 0;
    return 1 - (_remainingSeconds / _totalSeconds);
  }

  void _showCustomDialog() {
    setState(() => _customMode = true);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Custom duration', style: AppTextStyles.headlineSmall),
        content: TextField(
          controller: _customController,
          keyboardType: TextInputType.number,
          style: AppTextStyles.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Minutes (1–240)',
            hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
            suffix: Text('min', style: AppTextStyles.bodySmall),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppTextStyles.button.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(_customController.text.trim()) ?? 25;
              final clamped = val.clamp(1, 240);
              Navigator.pop(context);
              setState(() {
                _selectedDuration = clamped;
                _remainingSeconds = clamped * 60;
                _totalSeconds = clamped * 60;
              });
            },
            child: Text('Set', style: AppTextStyles.button.copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _showQuietHoursSheet() async {
    TimeOfDay startTime = _quietStart != null
        ? _parseHHmm(_quietStart!)
        : const TimeOfDay(hour: 21, minute: 0);
    TimeOfDay endTime = _quietEnd != null
        ? _parseHHmm(_quietEnd!)
        : const TimeOfDay(hour: 7, minute: 0);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(builder: (sheetCtx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 24,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Quiet Hours', style: AppTextStyles.headlineMedium),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ARIA will suppress all non-urgent notifications during these hours.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                _TimePickerRow(
                  label: 'Start',
                  time: startTime,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: sheetCtx,
                      initialTime: startTime,
                    );
                    if (picked != null) setSheet(() => startTime = picked);
                  },
                ),
                const SizedBox(height: 12),
                _TimePickerRow(
                  label: 'End',
                  time: endTime,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: sheetCtx,
                      initialTime: endTime,
                    );
                    if (picked != null) setSheet(() => endTime = picked);
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      setState(() {
                        _quietStart = _formatTimeOfDay(startTime);
                        _quietEnd = _formatTimeOfDay(endTime);
                      });
                      await _saveSmartFocusSettings();
                      if (mounted) Navigator.pop(sheetCtx);
                    },
                    child: const Text('Save', style: AppTextStyles.button),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _showAddBlockSheet() async {
    TimeOfDay start = TimeOfDay.now();
    TimeOfDay end = TimeOfDay(
      hour: (TimeOfDay.now().hour + 1) % 24,
      minute: TimeOfDay.now().minute,
    );
    String label = '';
    String type = 'focus';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(builder: (sheetCtx, setSheet) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 24,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Add Block', style: AppTextStyles.headlineMedium),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetCtx)),
                  ],
                ),
                const SizedBox(height: 16),
                // Type selector
                Row(
                  children: [
                    _BlockTypeChip(
                      label: 'Focus',
                      icon: Icons.timer_outlined,
                      selected: type == 'focus',
                      color: AppColors.success,
                      onTap: () => setSheet(() => type = 'focus'),
                    ),
                    const SizedBox(width: 10),
                    _BlockTypeChip(
                      label: 'Meeting',
                      icon: Icons.people_outline,
                      selected: type == 'meeting',
                      color: AppColors.accent,
                      onTap: () => setSheet(() => type = 'meeting'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => label = v,
                  decoration: InputDecoration(
                    labelText: 'Label (e.g. Deep Work, Standup)',
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _TimePickerRow(
                  label: 'Start',
                  time: start,
                  onTap: () async {
                    final picked = await showTimePicker(context: sheetCtx, initialTime: start);
                    if (picked != null) setSheet(() => start = picked);
                  },
                ),
                const SizedBox(height: 12),
                _TimePickerRow(
                  label: 'End',
                  time: end,
                  onTap: () async {
                    final picked = await showTimePicker(context: sheetCtx, initialTime: end);
                    if (picked != null) setSheet(() => end = picked);
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final block = {
                        'start': _formatTimeOfDay(start),
                        'end': _formatTimeOfDay(end),
                        'label': label.trim().isEmpty ? (type == 'meeting' ? 'Meeting' : 'Focus Block') : label.trim(),
                        'type': type,
                      };
                      setState(() => _focusBlocks.add(block));
                      await _saveSmartFocusSettings();
                      if (mounted) Navigator.pop(sheetCtx);
                    },
                    child: const Text('Add', style: AppTextStyles.button),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  TimeOfDay _parseHHmm(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Focus', style: AppTextStyles.headlineMedium),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              // Today's total focus time
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Today: $_todayFocusLabel',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 24),

              // ── Smart Focus Section ───────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Smart Focus',
                  style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 10),

              // DND during meetings card
              _SmartCard(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.do_not_disturb_on_outlined, color: AppColors.accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('DND During Meetings', style: AppTextStyles.labelLarge),
                          const SizedBox(height: 2),
                          Text(
                            'Silences distractions while you\'re in a meeting',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _dndMeetings,
                      activeColor: AppColors.accent,
                      onChanged: (v) async {
                        setState(() => _dndMeetings = v);
                        await _saveSmartFocusSettings();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Quiet Hours card
              GestureDetector(
                onTap: _showQuietHoursSheet,
                child: _SmartCard(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.bedtime_outlined, color: AppColors.secondary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Quiet Hours', style: AppTextStyles.labelLarge),
                            const SizedBox(height: 2),
                            Text(
                              (_quietStart != null && _quietEnd != null)
                                  ? '${_displayTime(_quietStart!)} – ${_displayTime(_quietEnd!)}'
                                  : 'Not set',
                              style: AppTextStyles.caption.copyWith(
                                color: (_quietStart != null) ? AppColors.textSecondary : AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Today's schedule
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Today\'s Schedule',
                      style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  GestureDetector(
                    onTap: _showAddBlockSheet,
                    child: Text(
                      '+ Add',
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_focusBlocks.isEmpty)
                GestureDetector(
                  onTap: _showAddBlockSheet,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                    ),
                    child: Center(
                      child: Text(
                        '+ Add a focus or meeting block',
                        style: AppTextStyles.labelMedium.copyWith(color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _focusBlocks.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      if (i == _focusBlocks.length) {
                        return GestureDetector(
                          onTap: _showAddBlockSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded, color: AppColors.textTertiary, size: 20),
                                const SizedBox(height: 2),
                                Text('Add', style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
                              ],
                            ),
                          ),
                        );
                      }
                      final block = _focusBlocks[i];
                      final isMeeting = block['type'] == 'meeting';
                      final color = isMeeting ? AppColors.accent : AppColors.success;
                      final icon = isMeeting ? Icons.people_outline : Icons.timer_outlined;
                      return GestureDetector(
                        onLongPress: () {
                          setState(() => _focusBlocks.removeAt(i));
                          _saveSmartFocusSettings();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, color: color, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    block['label'] as String? ?? '',
                                    style: AppTextStyles.labelSmall.copyWith(color: color),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_displayTime(block['start'] as String)} – ${_displayTime(block['end'] as String)}',
                                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              if (_focusBlocks.isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ARIA auto-enables focus mode during meeting blocks.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // ── Timer Section ─────────────────────────────────────────────
              // Duration picker — only visible when idle
              if (_timerState == _TimerState.idle) ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    ..._durationOptions.map((d) => _DurationChip(
                          label: '${d}m',
                          selected: _selectedDuration == d && !_customMode,
                          onTap: () => _setDuration(d),
                        )),
                    _DurationChip(
                      label: 'Custom',
                      selected: _customMode,
                      onTap: _showCustomDialog,
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ] else ...[
                const SizedBox(height: 8),
              ],
              // Circular timer / complete state
              if (_timerState != _TimerState.complete) ...[
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CustomPaint(
                    painter: _CircleTimerPainter(
                      progress: _progress,
                      trackColor: AppColors.surface,
                      progressColor: AppColors.accent,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _timeDisplay,
                            style: const TextStyle(
                              fontSize: 52,
                              fontWeight: FontWeight.w300,
                              color: AppColors.textPrimary,
                              letterSpacing: -2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _timerState == _TimerState.running
                                ? 'focusing'
                                : _timerState == _TimerState.paused
                                    ? 'paused'
                                    : '${_selectedDuration}m',
                            style: AppTextStyles.labelMedium.copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                // Session complete state
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.success, width: 3),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 56),
                      const SizedBox(height: 12),
                      Text(
                        'Session complete!',
                        style: AppTextStyles.headlineSmall.copyWith(color: AppColors.success),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedDuration}m focused',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              // Task input — only visible when idle
              if (_timerState == _TimerState.idle) ...[
                TextField(
                  controller: _taskController,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'What are you focusing on? (optional)',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {},
                ),
                const SizedBox(height: 32),
              ],
              // Action buttons
              if (_timerState == _TimerState.idle) ...[
                _PrimaryButton(label: 'Start Focus', onTap: _startTimer),
              ] else if (_timerState == _TimerState.running) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SecondaryButton(label: 'Pause', onTap: _pauseTimer),
                    const SizedBox(width: 12),
                    _SecondaryButton(label: 'Stop', onTap: _stopTimer),
                  ],
                ),
              ] else if (_timerState == _TimerState.paused) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PrimaryButton(label: 'Resume', onTap: _startTimer),
                    const SizedBox(width: 12),
                    _SecondaryButton(label: 'Stop', onTap: _stopTimer),
                  ],
                ),
              ] else if (_timerState == _TimerState.complete) ...[
                _PrimaryButton(
                  label: 'Start Another',
                  onTap: () => setState(() {
                    _timerState = _TimerState.idle;
                    _remainingSeconds = _selectedDuration * 60;
                    _totalSeconds = _selectedDuration * 60;
                  }),
                ),
              ],
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Smart Card wrapper ───────────────────────────────────────────────────────

class _SmartCard extends StatelessWidget {
  final Widget child;
  const _SmartCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

// ── Time picker row ──────────────────────────────────────────────────────────

class _TimePickerRow extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerRow({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final min = time.minute.toString().padLeft(2, '0');
    final display = '$hour:$min $period';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
            const Spacer(),
            Text(display, style: AppTextStyles.labelLarge),
            const SizedBox(width: 8),
            Icon(Icons.access_time_rounded, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Block type chip ──────────────────────────────────────────────────────────

class _BlockTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _BlockTypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? color : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.labelMedium.copyWith(
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Duration chip ────────────────────────────────────────────────────────────

class _DurationChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Buttons ──────────────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(32),
        ),
        child: Text(
          label,
          style: AppTextStyles.button.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: AppTextStyles.button.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

// ── Circular timer painter ───────────────────────────────────────────────────

class _CircleTimerPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;

  const _CircleTimerPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 10;

    // Track ring
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      // Progress arc
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircleTimerPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor;
}
