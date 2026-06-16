import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/aria_event.dart';
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
                        })
                    .toList();
                return PendingSuggestionsWidget(
                  suggestions: mapped,
                  onApprove: (s) async {
                    await ref
                        .read(eventsRepositoryProvider)
                        .approveEvent(s['id'] as String);
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
}
