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

  @override
  void initState() {
    super.initState();
    _loadTodayFocus();
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

  String _formatMinutes(int minutes) {
    if (minutes == 0) return '0m focused';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m focused';
    if (m == 0) return '${h}h focused';
    return '${h}h ${m}m focused';
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
              const SizedBox(height: 32),
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
                            style: TextStyle(
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
