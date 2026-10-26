import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/subscription.dart';
import '../../../../shared/providers/subscriptions_provider.dart';

const _kTrialOrange = Color(0xFFE67E22);
const _kTrialBg = Color(0xFFFFF3CD);
const _kTrialBorder = Color(0xFFFFB800);

class RenewalsScreen extends ConsumerStatefulWidget {
  const RenewalsScreen({super.key});

  @override
  ConsumerState<RenewalsScreen> createState() => _RenewalsScreenState();
}

class _RenewalsScreenState extends ConsumerState<RenewalsScreen> {
  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(subscriptionsProvider);
    final sorted = [...subs]..sort((a, b) =>
        a.daysUntilRenewal.compareTo(b.daysUntilRenewal));

    final trialsSoon = sorted
        .where((s) => s.isActive && s.isTrialEndingSoon)
        .toList();
    final overdue =
        sorted.where((s) => s.isActive && s.isOverdue).toList();
    final alertSoon = sorted
        .where((s) => s.isActive && !s.isOverdue && s.isAlertSoon)
        .toList();
    final upcoming = sorted
        .where((s) => s.isActive && !s.isOverdue && !s.isAlertSoon)
        .toList();
    final inactive = sorted.where((s) => !s.isActive).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(child: _buildSummaryBanner(subs)),
          // ── Trial billing alert ──────────────────────────────────────
          if (trialsSoon.isNotEmpty)
            SliverToBoxAdapter(
              child: _buildTrialAlertBanner(trialsSoon),
            ),
          // ── Sections ─────────────────────────────────────────────────
          if (overdue.isNotEmpty) ...[
            _sectionHeader('Expired — Renew Now', AppColors.error),
            ...overdue.map(_subTile),
          ],
          if (alertSoon.isNotEmpty) ...[
            _sectionHeader('Renewing Soon', AppColors.warning),
            ...alertSoon.map(_subTile),
          ],
          if (upcoming.isNotEmpty) ...[
            _sectionHeader('Upcoming', AppColors.textSecondary),
            ...upcoming.map(_subTile),
          ],
          if (inactive.isNotEmpty) ...[
            _sectionHeader('Inactive', AppColors.textTertiary),
            ...inactive.map(_subTile),
          ],
          if (subs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.subscriptions_outlined,
                        size: 52, color: AppColors.textTertiary),
                    const SizedBox(height: 16),
                    Text('No subscriptions yet',
                        style: AppTextStyles.headlineSmall
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text('Tap + to add your first one',
                        style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: const Color(0xFF0D0D15),
        onPressed: () => _showAddEditSheet(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTrialAlertBanner(List<Subscription> trials) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kTrialBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kTrialBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: _kTrialOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Trials billing soon',
                style: AppTextStyles.labelLarge
                    .copyWith(color: _kTrialOrange),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...trials.map((sub) {
            final endDate = sub.trialEndDate!;
            final dateStr =
                DateFormat('d MMM').format(endDate);
            final days = sub.daysUntilTrialEnd ?? 0;
            final whenStr =
                days == 0 ? 'today' : days == 1 ? 'tomorrow' : 'in $days days';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sub.name,
                            style: AppTextStyles.labelMedium
                                .copyWith(color: const Color(0xFF7D4E00))),
                        Text('Bills $whenStr ($dateStr)',
                            style: AppTextStyles.caption
                                .copyWith(color: _kTrialOrange)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref
                        .read(subscriptionsProvider.notifier)
                        .toggleActive(sub.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kTrialOrange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Cancel trial',
                          style: AppTextStyles.labelSmall
                              .copyWith(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppColors.background,
      floating: true,
      snap: true,
      elevation: 0,
      toolbarHeight: 64,
      title: const Text('Renewals & Subscriptions',
          style: AppTextStyles.headlineMedium),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.textSecondary, size: 20),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }

  Widget _buildSummaryBanner(List<Subscription> subs) {
    final active = subs.where((s) => s.isActive).toList();
    final overdue = active.where((s) => s.isOverdue).length;
    final alertSoon =
        active.where((s) => !s.isOverdue && s.isAlertSoon).length;
    final trials = active.where((s) => s.isTrial).length;

    Color bannerColor;
    String bannerText;
    IconData bannerIcon;

    if (overdue > 0) {
      bannerColor = AppColors.error;
      bannerText =
          '$overdue subscription${overdue > 1 ? 's' : ''} expired — action needed';
      bannerIcon = Icons.warning_amber_rounded;
    } else if (alertSoon > 0) {
      bannerColor = AppColors.warning;
      bannerText =
          '$alertSoon renewal${alertSoon > 1 ? 's' : ''} coming up soon';
      bannerIcon = Icons.notifications_active_outlined;
    } else if (trials > 0) {
      bannerColor = _kTrialOrange;
      bannerText = '$trials free trial${trials > 1 ? 's' : ''} active';
      bannerIcon = Icons.timer_outlined;
    } else {
      bannerColor = AppColors.success;
      bannerText = 'All ${active.length} subscriptions are up to date';
      bannerIcon = Icons.check_circle_outline;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bannerColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(bannerIcon, color: bannerColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(bannerText,
                style: AppTextStyles.bodySmall
                    .copyWith(color: bannerColor, height: 1.4)),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _sectionHeader(String title, Color color) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          title,
          style: AppTextStyles.labelMedium
              .copyWith(color: color, letterSpacing: 0.6),
        ),
      ),
    );
  }

  SliverToBoxAdapter _subTile(Subscription sub) {
    return SliverToBoxAdapter(
      child: _SubscriptionTile(
        subscription: sub,
        onEdit: () => _showAddEditSheet(context, sub),
        onToggle: () =>
            ref.read(subscriptionsProvider.notifier).toggleActive(sub.id),
        onDelete: () => _confirmDelete(sub),
      ),
    );
  }

  void _confirmDelete(Subscription sub) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete "${sub.name}"?',
            style: AppTextStyles.headlineSmall),
        content: Text('This will remove it from your tracker.',
            style: AppTextStyles.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(subscriptionsProvider.notifier).delete(sub.id);
              Navigator.pop(context);
            },
            child: Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showAddEditSheet(BuildContext context, Subscription? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddEditSheet(
        existing: existing,
        onSave: (sub) {
          if (existing == null) {
            ref.read(subscriptionsProvider.notifier).add(sub);
          } else {
            ref.read(subscriptionsProvider.notifier).update(sub);
          }
        },
      ),
    );
  }
}

// ── Tile ──────────────────────────────────────────────────────────────────────

class _SubscriptionTile extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _SubscriptionTile({
    required this.subscription,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  Color get _badgeColor {
    if (subscription.isOverdue) return AppColors.error;
    if (subscription.isAlertSoon) return AppColors.warning;
    return AppColors.success;
  }

  String get _badgeLabel {
    if (subscription.isOverdue) {
      final d = subscription.daysUntilRenewal.abs();
      return '$d day${d == 1 ? '' : 's'} overdue';
    }
    final d = subscription.daysUntilRenewal;
    if (d == 0) return 'today';
    if (d == 1) return 'tomorrow';
    return 'in $d days';
  }

  IconData get _categoryIcon {
    switch (subscription.category) {
      case 'streaming':
        return Icons.play_circle_outline_rounded;
      case 'utility':
        return Icons.cloud_outlined;
      case 'insurance':
        return Icons.health_and_safety_outlined;
      case 'app':
        return Icons.phone_iphone_rounded;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: subscription.isActive
                ? _badgeColor.withOpacity(
                    subscription.isAlertSoon || subscription.isOverdue
                        ? 0.3
                        : 0.12)
                : AppColors.border),
      ),
      child: InkWell(
        onTap: subscription.isAutoManaged ? null : onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_categoryIcon, color: _badgeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subscription.name,
                            style: AppTextStyles.labelLarge.copyWith(
                                color: subscription.isActive
                                    ? AppColors.textPrimary
                                    : AppColors.textTertiary),
                          ),
                        ),
                        if (subscription.isTrial) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _kTrialOrange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: _kTrialOrange.withOpacity(0.4)),
                            ),
                            child: Text('TRIAL',
                                style: AppTextStyles.labelSmall.copyWith(
                                    color: _kTrialOrange, fontSize: 9)),
                          ),
                        ],
                        if (subscription.isAutoManaged) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('AUTO',
                                style: AppTextStyles.labelSmall
                                    .copyWith(
                                        color: AppColors.accent,
                                        fontSize: 9)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (subscription.amountStr != null) ...[
                          Text(subscription.amountStr!,
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textTertiary)),
                          const SizedBox(width: 8),
                          Text('·',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.textTertiary)),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            subscription.isTrial
                                ? 'Trial ends $_badgeLabel'
                                : _badgeLabel,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: _badgeColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!subscription.isAutoManaged) ...[
                PopupMenuButton<String>(
                  color: AppColors.surfaceElevated,
                  icon: const Icon(Icons.more_vert,
                      color: AppColors.textTertiary, size: 20),
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'toggle') onToggle();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textPrimary))),
                    PopupMenuItem(
                        value: 'toggle',
                        child: Text(
                            subscription.isActive
                                ? 'Deactivate'
                                : 'Activate',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textPrimary))),
                    PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.error))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add / Edit sheet ──────────────────────────────────────────────────────────

class _AddEditSheet extends StatefulWidget {
  final Subscription? existing;
  final void Function(Subscription) onSave;

  const _AddEditSheet({this.existing, required this.onSave});

  @override
  State<_AddEditSheet> createState() => _AddEditSheetState();
}

class _AddEditSheetState extends State<_AddEditSheet> {
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _frequency = 'monthly';
  String _category = 'other';
  int _alertDays = 2;
  DateTime _renewalDate = DateTime.now().add(const Duration(days: 30));
  bool _isTrial = false;
  DateTime? _trialEndDate;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _amountCtrl.text = e.amountStr ?? '';
      _notesCtrl.text = e.notes ?? '';
      _frequency = e.frequency;
      _category = e.category;
      _alertDays = e.alertDaysBefore;
      _renewalDate = e.renewalDate;
      _isTrial = e.isTrial;
      _trialEndDate = e.trialEndDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(isEdit ? 'Edit Subscription' : 'Add Subscription',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 20),
            _field('Name', _nameCtrl,
                hint: 'e.g. Netflix, iCloud, Insurance'),
            const SizedBox(height: 12),
            _field('Amount (optional)', _amountCtrl, hint: 'e.g. ₹649/mo'),
            const SizedBox(height: 12),

            // ── Free Trial toggle ──────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isTrial
                    ? _kTrialBg
                    : AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _isTrial ? _kTrialBorder : AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined,
                      color: _isTrial ? _kTrialOrange : AppColors.textTertiary,
                      size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Free Trial',
                        style: AppTextStyles.labelMedium.copyWith(
                            color: _isTrial
                                ? _kTrialOrange
                                : AppColors.textSecondary)),
                  ),
                  Switch(
                    value: _isTrial,
                    activeColor: _kTrialOrange,
                    onChanged: (v) => setState(() {
                      _isTrial = v;
                      if (v && _trialEndDate == null) {
                        _trialEndDate =
                            DateTime.now().add(const Duration(days: 30));
                      }
                    }),
                  ),
                ],
              ),
            ),

            // ── Trial end date picker (shown when trial is on) ─────────
            if (_isTrial) ...[
              const SizedBox(height: 8),
              _labelText('Trial ends / billing starts'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        _trialEndDate ?? DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                          colorScheme: ColorScheme.light(
                              primary: _kTrialOrange,
                              surface: AppColors.surfaceElevated)),
                      child: child!,
                    ),
                  );
                  if (picked != null) {
                    setState(() {
                      _trialEndDate = picked;
                      _renewalDate = picked;
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                      color: _kTrialBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kTrialBorder)),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 16, color: _kTrialOrange),
                      const SizedBox(width: 10),
                      Text(
                        _trialEndDate != null
                            ? '${_trialEndDate!.day}/${_trialEndDate!.month}/${_trialEndDate!.year}'
                            : 'Pick date',
                        style: AppTextStyles.bodyMedium
                            .copyWith(color: _kTrialOrange),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 12),
            _labelText('Renewal Date'),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _renewalDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                        colorScheme: ColorScheme.dark(
                            primary: AppColors.accent,
                            surface: AppColors.surfaceElevated)),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _renewalDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 10),
                    Text(
                      '${_renewalDate.day}/${_renewalDate.month}/${_renewalDate.year}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _labelText('Frequency'),
            const SizedBox(height: 6),
            _dropdown(
              value: _frequency,
              items: const {
                'weekly': 'Weekly',
                'monthly': 'Monthly',
                'yearly': 'Yearly',
                'one_time': 'One-time',
              },
              onChanged: (v) => setState(() => _frequency = v!),
            ),
            const SizedBox(height: 12),
            _labelText('Category'),
            const SizedBox(height: 6),
            _dropdown(
              value: _category,
              items: const {
                'streaming': 'Streaming',
                'utility': 'Utility / Cloud',
                'insurance': 'Insurance',
                'app': 'App / Software',
                'other': 'Other',
              },
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),
            _labelText('Alert me $_alertDays days before'),
            Slider(
              value: _alertDays.toDouble(),
              min: 1,
              max: 14,
              divisions: 13,
              activeColor: AppColors.accent,
              inactiveColor: AppColors.border,
              label: '$_alertDays days',
              onChanged: (v) => setState(() => _alertDays = v.round()),
            ),
            _field('Notes (optional)', _notesCtrl,
                hint: 'Anything to remember'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child:
                    Text(isEdit ? 'Save Changes' : 'Add Subscription'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelText(label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }

  Widget _labelText(String text) => Text(text,
      style: AppTextStyles.labelMedium
          .copyWith(color: AppColors.textSecondary));

  Widget _dropdown({
    required String value,
    required Map<String, String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.surfaceElevated,
          style: AppTextStyles.bodyMedium,
          items: items.entries
              .map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final sub = Subscription(
      id: widget.existing?.id ??
          'sub_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      amountStr: _amountCtrl.text.trim().isEmpty
          ? null
          : _amountCtrl.text.trim(),
      renewalDate: _renewalDate,
      frequency: _frequency,
      alertDaysBefore: _alertDays,
      notes: _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      category: _category,
      isActive: widget.existing?.isActive ?? true,
      isAutoManaged: false,
      isTrial: _isTrial,
      trialEndDate: _isTrial ? _trialEndDate : null,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    widget.onSave(sub);
    Navigator.pop(context);
  }
}
