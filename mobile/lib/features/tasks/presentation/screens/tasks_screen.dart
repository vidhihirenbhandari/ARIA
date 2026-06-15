import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/aria_task.dart';
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

  List<AriaTask> get _pending => _tasks.where((t) => t.status == 'pending').toList();
  List<AriaTask> get _completed => _tasks.where((t) => t.status == 'completed').toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
            icon: const Icon(Icons.add_rounded, color: AppColors.accent),
            onPressed: _showAddTask,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
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
    );
  }

  Widget _buildTaskList(List<AriaTask> tasks) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.task_alt_outlined, color: AppColors.textTertiary, size: 56),
            const SizedBox(height: 16),
            Text(
              tasks == _pending ? 'All caught up!' : 'No completed tasks yet',
              style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textTertiary),
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                decoration: const InputDecoration(
                  hintText: 'What needs to be done?',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accent, width: 2),
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
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Add Task', style: AppTextStyles.button),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
