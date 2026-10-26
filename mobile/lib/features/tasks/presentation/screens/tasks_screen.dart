import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/aria_task.dart';
import '../../../../shared/models/commitment.dart';
import '../../../../shared/providers/commitments_provider.dart';
import '../widgets/task_card.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _addController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;

  final List<AriaTask> _tasks = [
    AriaTask(
      id: '1',
      userId: 'u1',
      title: 'Send proposal to Raj',
      priority: 'high',
      status: 'pending',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      source: 'memory',
    ),
    AriaTask(
      id: '2',
      userId: 'u1',
      title: 'Review Q4 budget report',
      priority: 'medium',
      status: 'pending',
      dueDate: DateTime.now().add(const Duration(days: 5)),
      source: 'manual',
    ),
    AriaTask(
      id: '3',
      userId: 'u1',
      title: 'Book dentist appointment',
      priority: 'low',
      status: 'pending',
      dueDate: DateTime.now().add(const Duration(days: 10)),
      source: 'manual',
    ),
    AriaTask(
      id: '4',
      userId: 'u1',
      title: 'Update team on project status',
      priority: 'high',
      status: 'completed',
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      source: 'manual',
    ),
  ];

  List<AriaTask> get _pending =>
      _tasks.where((t) => t.status == 'pending').toList();
  List<AriaTask> get _completed =>
      _tasks.where((t) => t.status == 'completed').toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (_) {},
      onStatus: (_) {},
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _addController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Tasks', style: AppTextStyles.headlineLarge),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: AppColors.accent),
            onPressed: _showAddTask,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Pending (${_pending.length})'),
            Tab(text: 'Done (${_completed.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTaskList(_pending),
          _buildTaskList(_completed),
        ],
      ),
      floatingActionButton: _buildVoiceFAB(),
    );
  }

  Widget _buildVoiceFAB() {
    return FloatingActionButton(
      onPressed: _showVoiceSheet,
      backgroundColor: AppColors.accent,
      elevation: 6,
      child: const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
    );
  }

  Widget _buildTaskList(List<AriaTask> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task_alt_outlined,
                color: AppColors.textTertiary, size: 56),
            const SizedBox(height: 16),
            Text(
              tasks == _pending ? 'All caught up!' : 'No completed tasks yet',
              style: AppTextStyles.headlineSmall
                  .copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: tasks.length,
      itemBuilder: (_, i) => TaskCard(
        task: tasks[i],
        onToggle: () => _toggleTask(tasks[i]),
        onDelete: () => _deleteTask(tasks[i]),
      ),
    );
  }

  void _toggleTask(AriaTask task) {
    setState(() {
      final index = _tasks.indexOf(task);
      _tasks[index] = task.copyWith(
        status: task.status == 'completed' ? 'pending' : 'completed',
      );
    });
  }

  void _deleteTask(AriaTask task) {
    setState(() => _tasks.remove(task));
  }

  void _showAddTask() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Task', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 16),
              TextField(
                controller: _addController,
                style: const TextStyle(color: AppColors.textPrimary),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle:
                      const TextStyle(color: AppColors.textTertiary),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide:
                        BorderSide(color: AppColors.accent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_addController.text.trim().isNotEmpty) {
                      setState(() {
                        _tasks.add(AriaTask(
                          id: DateTime.now()
                              .millisecondsSinceEpoch
                              .toString(),
                          userId: 'u1',
                          title: _addController.text.trim(),
                          priority: 'medium',
                          status: 'pending',
                          source: 'manual',
                        ));
                      });
                      _addController.clear();
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child:
                      const Text('Add Task', style: AppTextStyles.button),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── Voice capture ──────────────────────────────────────────────────────────

  void _showVoiceSheet() {
    if (_speechAvailable) {
      _showRecordingSheet();
    } else {
      _showFallbackTextSheet();
    }
  }

  void _showRecordingSheet() {
    final transcribedController = TextEditingController();
    bool isListening = false;
    bool hasResult = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          void startListening() async {
            setSheetState(() {
              isListening = true;
              hasResult = false;
              transcribedController.clear();
            });
            await _speech.listen(
              onResult: (result) {
                setSheetState(() {
                  transcribedController.text = result.recognizedWords;
                  if (result.finalResult) {
                    isListening = false;
                    hasResult = true;
                  }
                });
              },
              listenFor: const Duration(seconds: 20),
              pauseFor: const Duration(seconds: 3),
              listenMode: stt.ListenMode.confirmation,
            );
          }

          void stopListening() async {
            await _speech.stop();
            setSheetState(() => isListening = false);
          }

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Voice Capture',
                          style: AppTextStyles.headlineMedium),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textSecondary),
                        onPressed: () {
                          _speech.stop();
                          Navigator.pop(sheetCtx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Animated pulse mic
                  GestureDetector(
                    onTap: isListening ? stopListening : startListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: isListening ? 80 : 72,
                      height: isListening ? 80 : 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isListening
                            ? AppColors.error.withOpacity(0.15)
                            : AppColors.accent.withOpacity(0.12),
                        border: Border.all(
                          color: isListening
                              ? AppColors.error
                              : AppColors.accent,
                          width: 2,
                        ),
                        boxShadow: isListening
                            ? [
                                BoxShadow(
                                  color: AppColors.error.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                )
                              ]
                            : [],
                      ),
                      child: Icon(
                        isListening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: isListening
                            ? AppColors.error
                            : AppColors.accent,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isListening
                        ? 'Listening...'
                        : hasResult
                            ? 'Tap to re-record'
                            : 'Tap to start',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isListening
                          ? AppColors.error
                          : AppColors.textTertiary,
                    ),
                  ),
                  if (hasResult || isListening) ...[
                    const SizedBox(height: 20),
                    TextField(
                      controller: transcribedController,
                      style: const TextStyle(color: AppColors.textPrimary),
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Transcribed text...',
                        hintStyle:
                            const TextStyle(color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                  if (hasResult) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final text = transcribedController.text.trim();
                          if (text.isNotEmpty) {
                            _saveVoiceTask(text, sheetCtx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Save Task',
                            style: AppTextStyles.button),
                      ),
                    ),
                  ] else if (!isListening) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: startListening,
                      child: Text(
                        'Start recording',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.accent),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );

    // auto-start listening when sheet opens
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (_speech.isAvailable && !_speech.isListening) {
        // will be handled by user tapping — already shows instructions
      }
    });
  }

  void _showFallbackTextSheet() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quick Capture', style: AppTextStyles.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Voice not available — type your task',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'e.g. "Remind Raj to send report tomorrow"',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isNotEmpty) {
                      _saveVoiceTask(text, sheetCtx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save Task', style: AppTextStyles.button),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _saveVoiceTask(String text, BuildContext sheetCtx) {
    final dueDate = _extractDate(text);
    final commitment = Commitment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      person: '',
      direction: 'i_promised',
      dueDate: dueDate,
      createdAt: DateTime.now(),
      source: 'voice',
    );
    ref.read(commitmentsProvider.notifier).addCommitment(commitment);

    // Also add to local tasks list for immediate UI feedback
    setState(() {
      _tasks.add(AriaTask(
        id: commitment.id,
        userId: 'u1',
        title: text,
        priority: 'medium',
        status: 'pending',
        dueDate: dueDate,
        source: 'voice',
      ));
    });

    Navigator.pop(sheetCtx);

    final shortText =
        text.length > 40 ? '${text.substring(0, 40)}…' : text;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task added: $shortText'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Extract a simple date hint from spoken text.
  DateTime? _extractDate(String text) {
    final lower = text.toLowerCase();
    final now = DateTime.now();
    if (lower.contains('tomorrow')) {
      return now.add(const Duration(days: 1));
    }
    if (lower.contains('next week')) {
      return now.add(const Duration(days: 7));
    }
    final weekdays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };
    for (final entry in weekdays.entries) {
      if (lower.contains(entry.key) || lower.contains('on ${entry.key}')) {
        int daysUntil = entry.value - now.weekday;
        if (daysUntil <= 0) daysUntil += 7;
        return now.add(Duration(days: daysUntil));
      }
    }
    return null;
  }
}
