import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/aria_event.dart';
import '../../../../shared/providers/calendar_events_provider.dart';
import '../../../../shared/providers/commitments_provider.dart';
import '../../../../shared/providers/people_provider.dart';
import '../../../../shared/providers/subscriptions_provider.dart';
import '../../data/briefing_repository.dart';
import '../../../assistant/data/events_repository.dart';
import '../widgets/daily_briefing_card.dart';
import '../widgets/upcoming_events_widget.dart';
import '../widgets/pending_suggestions_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Today's calendar events — Phase 2 will pull from calendar API
  final List<Event> _todayEvents = [
    Event(
      id: '1',
      userId: 'u1',
      title: 'Team Standup',
      startTime: DateTime.now().copyWith(hour: 10, minute: 0),
      endTime: DateTime.now().copyWith(hour: 10, minute: 30),
      source: 'google_calendar',
      status: 'approved',
    ),
    Event(
      id: '2',
      userId: 'u1',
      title: 'Client Call — Raj Sharma',
      startTime: DateTime.now().copyWith(hour: 14, minute: 0),
      endTime: DateTime.now().copyWith(hour: 15, minute: 0),
      location: 'Google Meet',
      source: 'google_calendar',
      status: 'approved',
    ),
    Event(
      id: '3',
      userId: 'u1',
      title: 'Product Review',
      startTime: DateTime.now().copyWith(hour: 16, minute: 30),
      endTime: DateTime.now().copyWith(hour: 17, minute: 30),
      source: 'google_calendar',
      status: 'approved',
    ),
  ];

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final briefingAsync = ref.watch(dailyBriefingProvider);
    final suggestionsAsync = ref.watch(pendingSuggestionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: const SizedBox(height: 16)),
          // Daily briefing card — live from API with shimmer fallback
          SliverToBoxAdapter(
            child: briefingAsync.when(
              data: (briefing) => DailyBriefingCard(
                assistantName: 'ARIA',
                greeting: '${briefing.greeting}, Vidhi',
                summary: briefing.summary.isNotEmpty
                    ? briefing.summary
                    : 'You have ${_todayEvents.length} meetings today.',
                meetingsCount: briefing.meetingsCount > 0
                    ? briefing.meetingsCount
                    : _todayEvents.length,
                tasksCount: briefing.tasksCount,
                pendingCount: briefing.pendingCount,
              ),
              loading: () => _buildBriefingShimmer(),
              error: (_, __) => DailyBriefingCard(
                assistantName: 'ARIA',
                greeting: '$_greeting, Vidhi',
                summary: 'You have ${_todayEvents.length} meetings today.',
                meetingsCount: _todayEvents.length,
                tasksCount: 0,
                pendingCount: 0,
              ),
            ),
          ),
          // Pending suggestions — live from API
          SliverToBoxAdapter(
            child: suggestionsAsync.when(
              data: (suggestions) {
                if (suggestions.isEmpty) return const SizedBox.shrink();
                final mapped = suggestions
                    .map((e) => {
                          'id': e.id,
                          'title': e.title,
                          'description': e.description ?? '',
                          'confidence': e.confidenceScore ?? 0.9,
                          'type': e.source,
                          'startTime': e.startTime,
                          'endTime': e.endTime,
                          'location': e.location,
                        })
                    .toList();
                return PendingSuggestionsWidget(
                  suggestions: mapped,
                  onApprove: (s) async {
                    await ref
                        .read(eventsRepositoryProvider)
                        .approveEvent(s['id'] as String);
                    final approvedEvent = Event(
                      id: s['id'] as String,
                      userId: 'demo-user',
                      title: s['title'] as String,
                      startTime: s['startTime'] as DateTime,
                      endTime: s['endTime'] as DateTime,
                      location: s['location'] as String?,
                      source: s['type'] as String,
                      status: 'approved',
                    );
                    ref.read(calendarEventsProvider.notifier).addEvent(approvedEvent);
                    ref.invalidate(pendingSuggestionsProvider);
                  },
                  onIgnore: (s) async {
                    await ref
                        .read(eventsRepositoryProvider)
                        .rejectEvent(s['id'] as String);
                    ref.invalidate(pendingSuggestionsProvider);
                  },
                );
              },
              loading: () => _buildSuggestionsShimmer(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          // ARIA Insights — proactive intelligence
          SliverToBoxAdapter(child: _buildAriaInsights()),
          SliverToBoxAdapter(child: const SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: UpcomingEventsWidget(events: _todayEvents),
          ),
          SliverToBoxAdapter(child: const SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildQuickActions()),
          SliverToBoxAdapter(child: const SizedBox(height: 32)),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildBriefingShimmer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 140,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildSuggestionsShimmer() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      floating: true,
      snap: true,
      elevation: 0,
      expandedHeight: 0,
      toolbarHeight: 72,
      flexibleSpace: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _greeting,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                    ),
                    const Text('Vidhi', style: AppTextStyles.headlineLarge),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/settings'),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: AppColors.textSecondary, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      {'icon': Icons.add_outlined, 'label': 'Add Event', 'route': '/home/calendar'},
      {'icon': Icons.task_outlined, 'label': 'New Task', 'route': '/home/tasks'},
      {'icon': Icons.subscriptions_outlined, 'label': 'Renewals', 'route': '/home/renewals'},
      {'icon': Icons.flight_outlined, 'label': 'Travel', 'route': '/travel'},
      {'icon': Icons.psychology_outlined, 'label': 'Memory', 'route': '/home/memory'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text('Quick Actions', style: AppTextStyles.headlineSmall),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: actions.length,
            itemBuilder: (_, i) {
              final action = actions[i];
              return GestureDetector(
                onTap: () => context.go(action['route'] as String),
                child: Container(
                  width: 88,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(action['icon'] as IconData, color: AppColors.accent, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action['label'] as String,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return GestureDetector(
      onTap: () => context.go('/home/chat'),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildAriaInsights() {
    final commitments = ref.watch(commitmentsProvider);
    final people = ref.watch(peopleProvider);
    final subscriptions = ref.watch(subscriptionsProvider);
    final now = DateTime.now();

    final insights = <_InsightItem>[];

    // Subscription / renewal alerts
    for (final s in subscriptions) {
      if (!s.isActive) continue;
      if (s.isOverdue) {
        final d = s.daysUntilRenewal.abs();
        insights.insert(
          0,
          _InsightItem(
            icon: Icons.warning_amber_rounded,
            color: AppColors.error,
            text: '${s.name} expired $d day${d == 1 ? '' : 's'} ago — renew now',
            route: '/home/renewals',
          ),
        );
      } else if (s.isAlertSoon) {
        final d = s.daysUntilRenewal;
        final label = d == 0 ? 'today' : d == 1 ? 'tomorrow' : 'in $d days';
        insights.add(_InsightItem(
          icon: Icons.notifications_active_outlined,
          color: AppColors.warning,
          text: '${s.name} renews $label${s.amountStr != null ? ' (${s.amountStr})' : ''}',
          route: '/home/renewals',
        ));
      }
    }

    for (final c in commitments) {
      if (!c.isCompleted && c.dueDate != null && c.dueDate!.isBefore(now) && c.direction == 'i_promised') {
        final daysAgo = now.difference(c.dueDate!).inDays;
        insights.add(_InsightItem(
          icon: Icons.warning_amber_rounded,
          color: AppColors.error,
          text: 'You promised to "${c.text}" for ${c.person} — due $daysAgo day${daysAgo == 1 ? '' : 's'} ago',
          route: '/home/tasks',
        ));
      }
    }

    for (final c in commitments) {
      if (!c.isCompleted && c.dueDate != null && c.dueDate!.isAfter(now) && c.dueDate!.difference(now).inDays <= 3 && c.direction == 'i_promised') {
        final daysLeft = c.dueDate!.difference(now).inDays;
        final dayLabel = daysLeft == 0 ? 'today' : daysLeft == 1 ? 'tomorrow' : 'in $daysLeft days';
        insights.add(_InsightItem(
          icon: Icons.access_time_rounded,
          color: AppColors.accent,
          text: 'Reminder: "${c.text}" — due $dayLabel',
          route: '/home/tasks',
        ));
      }
    }

    for (final p in people) {
      if (p.followUpDate != null && p.followUpDate!.isBefore(now)) {
        insights.add(_InsightItem(
          icon: Icons.person_outline_rounded,
          color: AppColors.warning,
          text: 'Follow up with ${p.name}${p.followUpNote != null ? ': ${p.followUpNote}' : ''}',
          route: '/home/people',
        ));
      }
      if (p.lastContact != null && now.difference(p.lastContact!).inDays >= 14) {
        insights.add(_InsightItem(
          icon: Icons.person_outline_rounded,
          color: AppColors.warning,
          text: "Haven't been in touch with ${p.name} in ${now.difference(p.lastContact!).inDays} days",
          route: '/home/people',
        ));
      }
    }

    if (insights.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.check_circle_outline, color: AppColors.success, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "You're all caught up. ARIA is watching your schedule.",
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('ARIA Insights', style: AppTextStyles.headlineSmall),
        ),
        ...insights.take(4).map((item) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: GestureDetector(
            onTap: () => context.go(item.route),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: item.color.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(item.icon, color: item.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.text,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
        )),
      ],
    );
  }
}

class _InsightItem {
  final IconData icon;
  final Color color;
  final String text;
  final String route;
  const _InsightItem({required this.icon, required this.color, required this.text, required this.route});
}
