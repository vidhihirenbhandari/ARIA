import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_text_styles.dart';
import 'features/dashboard/presentation/screens/dashboard_screen.dart';
import 'features/inbox/presentation/screens/inbox_screen.dart';
import 'features/assistant/presentation/screens/chat_screen.dart';
import 'features/people/presentation/screens/people_screen.dart';
import 'features/tasks/presentation/screens/tasks_screen.dart';
import 'shared/models/commitment.dart';
import 'shared/models/person_context.dart';
import 'shared/models/subscription.dart';
import 'shared/providers/commitments_provider.dart';
import 'shared/providers/people_provider.dart';
import 'shared/providers/subscriptions_provider.dart';

final _navIndexProvider = StateProvider<int>((ref) => 0);

class MainNavigation extends ConsumerWidget {
  // child kept for ShellRoute compatibility but ignored — we use IndexedStack
  final Widget child;
  const MainNavigation({super.key, required this.child});

  static const _screens = [
    DashboardScreen(),
    InboxScreen(),
    ChatScreen(),
    PeopleScreen(),
    TasksScreen(),
  ];

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_outlined,         activeIcon: Icons.home_rounded,           label: 'Home',   isCenter: false),
    _NavItem(icon: Icons.inbox_outlined,         activeIcon: Icons.move_to_inbox_rounded,  label: 'Inbox',  isCenter: false),
    _NavItem(icon: Icons.auto_awesome_outlined,  activeIcon: Icons.auto_awesome_rounded,   label: 'ARIA',   isCenter: true),
    _NavItem(icon: Icons.people_outline,         activeIcon: Icons.people_rounded,         label: 'People', isCenter: false),
    _NavItem(icon: Icons.task_outlined,          activeIcon: Icons.task_rounded,           label: 'Tasks',  isCenter: false),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(_navIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      floatingActionButton: const _QuickCaptureFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: _navItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final isActive = currentIndex == index;

                if (item.isCenter) {
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => ref.read(_navIndexProvider.notifier).state = index,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          gradient: AppColors.accentGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => ref.read(_navIndexProvider.notifier).state = index,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            isActive ? item.activeIcon : item.icon,
                            key: ValueKey(isActive),
                            color: isActive ? AppColors.accent : AppColors.textTertiary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: isActive ? AppColors.accent : AppColors.textTertiary,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          ),
                          child: Text(item.label),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Quick Capture FAB ──────────────────────────────────────────────────────────

class _QuickCaptureFAB extends StatelessWidget {
  const _QuickCaptureFAB();

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showQuickCapture(context),
      backgroundColor: AppColors.surfaceElevated,
      elevation: 4,
      child: const Icon(Icons.add_rounded, color: AppColors.textPrimary, size: 28),
    );
  }

  void _showQuickCapture(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => const _QuickCaptureSheet(),
    );
  }
}

// ── Quick Capture Sheet ────────────────────────────────────────────────────────

class _QuickCaptureSheet extends ConsumerStatefulWidget {
  const _QuickCaptureSheet();

  @override
  ConsumerState<_QuickCaptureSheet> createState() =>
      _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<_QuickCaptureSheet> {
  // Which tile is expanded: null = none, 'task'|'person'|'sub'|'paste'
  String? _expanded;

  // Task fields
  final _taskCtrl = TextEditingController();

  // Person fields
  final _personNameCtrl = TextEditingController();
  String _personRelationship = 'colleague';

  // Subscription fields
  final _subNameCtrl = TextEditingController();
  DateTime _subRenewal = DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _taskCtrl.dispose();
    _personNameCtrl.dispose();
    _subNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle + title row
              Row(
                children: [
                  const Text('Quick Add', style: AppTextStyles.headlineMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTile(
                key: 'task',
                emoji: '📝',
                label: 'Task',
                subtitle: 'Add a commitment or to-do',
                expandedChild: _buildTaskForm(),
              ),
              const SizedBox(height: 10),
              _buildTile(
                key: 'person',
                emoji: '👤',
                label: 'Person',
                subtitle: 'Save a contact to follow up on',
                expandedChild: _buildPersonForm(),
              ),
              const SizedBox(height: 10),
              _buildTile(
                key: 'sub',
                emoji: '🔔',
                label: 'Subscription',
                subtitle: 'Track a renewal or payment',
                expandedChild: _buildSubForm(),
              ),
              const SizedBox(height: 10),
              _buildTile(
                key: 'paste',
                emoji: '💬',
                label: 'Paste & Extract',
                subtitle: 'Let ARIA parse any text you paste',
                expandedChild: const SizedBox.shrink(),
                onTap: () {
                  Navigator.pop(context);
                  context.go('/home/inbox');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile({
    required String key,
    required String emoji,
    required String label,
    required String subtitle,
    required Widget expandedChild,
    VoidCallback? onTap,
  }) {
    final isExpanded = _expanded == key;

    return GestureDetector(
      onTap: onTap ??
          () => setState(
              () => _expanded = isExpanded ? null : key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isExpanded
              ? AppColors.surfaceElevated
              : AppColors.surfaceElevated.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpanded ? AppColors.accent.withOpacity(0.4) : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: AppTextStyles.labelLarge),
                        Text(subtitle, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
            if (isExpanded) ...[
              Divider(
                  color: AppColors.border, height: 1, indent: 14, endIndent: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: expandedChild,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Task form ──────────────────────────────────────────────────────────────

  Widget _buildTaskForm() {
    return Column(
      children: [
        TextField(
          controller: _taskCtrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'What needs to be done?',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveTask,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Task', style: AppTextStyles.button),
          ),
        ),
      ],
    );
  }

  void _saveTask() {
    final text = _taskCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(commitmentsProvider.notifier).addCommitment(
          Commitment(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text: text,
            person: '',
            direction: 'i_promised',
            createdAt: DateTime.now(),
            source: 'quick_capture',
          ),
        );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task added: $text'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Person form ────────────────────────────────────────────────────────────

  Widget _buildPersonForm() {
    final relationships = [
      'colleague', 'friend', 'family', 'client', 'vendor', 'other'
    ];

    return Column(
      children: [
        TextField(
          controller: _personNameCtrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Full name',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: _personRelationship,
          dropdownColor: AppColors.surfaceElevated,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: relationships
              .map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(
                      r[0].toUpperCase() + r.substring(1),
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _personRelationship = v);
          },
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _savePerson,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Person', style: AppTextStyles.button),
          ),
        ),
      ],
    );
  }

  void _savePerson() {
    final name = _personNameCtrl.text.trim();
    if (name.isEmpty) return;
    ref.read(peopleProvider.notifier).addPerson(
          PersonContext(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            relationship: _personRelationship,
            createdAt: DateTime.now(),
          ),
        );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name added to People'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Subscription form ──────────────────────────────────────────────────────

  Widget _buildSubForm() {
    return Column(
      children: [
        TextField(
          controller: _subNameCtrl,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Service name (e.g. Spotify)',
            hintStyle: const TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _subRenewal,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              builder: (ctx, child) => Theme(
                data: ThemeData.dark().copyWith(
                  colorScheme: ColorScheme.dark(primary: AppColors.accent),
                ),
                child: child!,
              ),
            );
            if (picked != null) setState(() => _subRenewal = picked);
          },
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Renewal: ${_subRenewal.day}/${_subRenewal.month}/${_subRenewal.year}',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveSubscription,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Add Subscription',
                style: AppTextStyles.button),
          ),
        ),
      ],
    );
  }

  void _saveSubscription() {
    final name = _subNameCtrl.text.trim();
    if (name.isEmpty) return;
    ref.read(subscriptionsProvider.notifier).add(
          Subscription(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: name,
            renewalDate: _subRenewal,
            createdAt: DateTime.now(),
          ),
        );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name added to Subscriptions'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isCenter;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isCenter,
  });
}
