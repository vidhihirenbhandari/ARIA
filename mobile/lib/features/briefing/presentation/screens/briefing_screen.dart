import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/commitment.dart';
import '../../../../shared/models/person_context.dart';
import '../../../../shared/models/subscription.dart';
import '../../../../shared/providers/commitments_provider.dart';
import '../../../../shared/providers/people_provider.dart';
import '../../../../shared/providers/subscriptions_provider.dart';

class BriefingScreen extends ConsumerWidget {
  const BriefingScreen({super.key});

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commitments = ref.watch(commitmentsProvider);
    final people = ref.watch(peopleProvider);
    final subscriptions = ref.watch(subscriptionsProvider);
    final now = DateTime.now();

    final overdueCommitments = commitments
        .where((c) =>
            !c.isCompleted &&
            c.dueDate != null &&
            c.dueDate!.isBefore(now))
        .toList();

    final peopleToReach = people.where((p) {
      final followUpDue =
          p.followUpDate != null && p.followUpDate!.isBefore(now);
      final longNoContact = p.lastContact != null &&
          now.difference(p.lastContact!).inDays >= 14;
      return followUpDue || longNoContact;
    }).toList();

    final alertSubs = subscriptions
        .where((s) => s.isActive && (s.isAlertSoon || s.isOverdue))
        .toList();

    final allClear =
        overdueCommitments.isEmpty && peopleToReach.isEmpty && alertSubs.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreetingCard(),
                  const SizedBox(height: 20),
                  if (allClear) _buildAllClear() else ...[
                    if (overdueCommitments.isNotEmpty) ...[
                      _buildSection(
                        title: "Today's Focus",
                        icon: Icons.flag_outlined,
                        iconColor: AppColors.error,
                        children: overdueCommitments
                            .map((c) => _buildCommitmentTile(c, now))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (peopleToReach.isNotEmpty) ...[
                      _buildSection(
                        title: 'People to reach',
                        icon: Icons.people_outline_rounded,
                        iconColor: AppColors.warning,
                        children: peopleToReach
                            .map((p) => _buildPersonTile(p, now))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (alertSubs.isNotEmpty) ...[
                      _buildSection(
                        title: 'Renewals',
                        icon: Icons.subscriptions_outlined,
                        iconColor: AppColors.secondary,
                        children: alertSubs
                            .map((s) => _buildSubTile(s))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                  const SizedBox(height: 8),
                  _buildStartButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      floating: true,
      snap: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.textSecondary, size: 20),
        onPressed: () => context.pop(),
      ),
      title: const Text('Morning Brief', style: AppTextStyles.headlineMedium),
    );
  }

  Widget _buildGreetingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                _greeting,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Vidhi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(DateTime.now()),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month]} ${dt.year}';
  }

  Widget _buildAllClear() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.success, size: 30),
          ),
          const SizedBox(height: 12),
          Text(
            'All clear!',
            style: AppTextStyles.headlineMedium.copyWith(color: AppColors.success),
          ),
          const SizedBox(height: 6),
          Text(
            'No overdue tasks, no follow-ups, no renewals due.\nYou\'re in great shape.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 16),
            ),
            const SizedBox(width: 10),
            Text(title, style: AppTextStyles.headlineSmall),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildCommitmentTile(Commitment c, DateTime now) {
    final daysAgo = now.difference(c.dueDate!).inDays;
    final label = daysAgo == 0
        ? 'due today'
        : daysAgo == 1
            ? 'due yesterday'
            : '$daysAgo days overdue';
    return _buildTile(
      icon: Icons.task_alt_outlined,
      iconColor: AppColors.error,
      title: c.text,
      subtitle: '${c.person.isNotEmpty ? c.person + ' · ' : ''}$label',
    );
  }

  Widget _buildPersonTile(PersonContext p, DateTime now) {
    String subtitle;
    if (p.followUpDate != null && p.followUpDate!.isBefore(now)) {
      subtitle = p.followUpNote ?? 'Follow-up overdue';
    } else {
      final days = now.difference(p.lastContact!).inDays;
      subtitle = 'Last contact $days days ago';
    }
    return _buildTile(
      icon: Icons.person_outline_rounded,
      iconColor: AppColors.warning,
      title: p.name,
      subtitle: subtitle,
    );
  }

  Widget _buildSubTile(Subscription s) {
    final label = s.isOverdue
        ? 'Overdue — ${s.amountStr ?? ''}'.trim()
        : 'Due in ${s.daysUntilRenewal} days${s.amountStr != null ? ' · ${s.amountStr}' : ''}';
    return _buildTile(
      icon: Icons.subscriptions_outlined,
      iconColor: s.isOverdue ? AppColors.error : AppColors.secondary,
      title: s.name,
      subtitle: label,
    );
  }

  Widget _buildTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: () => context.go('/home/chat'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withOpacity(0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Start my day',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
