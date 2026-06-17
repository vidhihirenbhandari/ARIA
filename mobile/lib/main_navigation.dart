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
