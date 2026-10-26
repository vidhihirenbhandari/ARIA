import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/watch_item.dart';
import '../../../../shared/providers/watchlist_provider.dart';

const _typeColors = {
  WatchType.flight: Color(0xFF3A7BD5),
  WatchType.deadline: Color(0xFFEF4444),
  WatchType.price: Color(0xFF10B981),
  WatchType.subscription: Color(0xFFE8803A),
  WatchType.custom: Color(0xFF6B7280),
};

const _typeIcons = {
  WatchType.flight: Icons.flight,
  WatchType.deadline: Icons.timer_outlined,
  WatchType.price: Icons.sell_outlined,
  WatchType.subscription: Icons.repeat,
  WatchType.custom: Icons.visibility_outlined,
};

const _typeLabels = {
  WatchType.flight: 'Flight',
  WatchType.deadline: 'Deadline',
  WatchType.price: 'Price',
  WatchType.subscription: 'Subscription',
  WatchType.custom: 'Custom',
};

class WatchlistScreen extends ConsumerStatefulWidget {
  const WatchlistScreen({super.key});

  @override
  ConsumerState<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends ConsumerState<WatchlistScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _alertLabel(DateTime? alertDate) {
    if (alertDate == null) return '';
    final diff = alertDate.difference(DateTime.now()).inDays;
    if (diff < 0) return 'Alert: overdue';
    if (diff == 0) return 'Alert: today';
    if (diff == 1) return 'Alert: tomorrow';
    return 'Alert: in $diff days';
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(watchlistProvider);
    final active = all.where((w) => !w.isResolved).toList();
    final done = all.where((w) => w.isResolved).toList();

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
        title: const Text('Watch List', style: AppTextStyles.headlineMedium),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: AppTextStyles.labelMedium,
          tabs: [
            Tab(text: 'Watching (${active.length})'),
            Tab(text: 'Done (${done.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(active, showActions: true),
          _buildList(done, showActions: false),
        ],
      ),
    );
  }

  Widget _buildList(List<WatchItem> items, {required bool showActions}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.visibility_outlined, size: 34, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            Text(
              showActions ? 'Nothing on watch' : 'Nothing resolved yet',
              style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              showActions ? 'Tap + to add a flight, deadline, or price to track' : '',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: items.length,
      itemBuilder: (_, i) => _buildCard(items[i], showActions: showActions),
    );
  }

  Widget _buildCard(WatchItem item, {required bool showActions}) {
    final color = _typeColors[item.type] ?? const Color(0xFF6B7280);
    final icon = _typeIcons[item.type] ?? Icons.visibility_outlined;
    final alertLabel = _alertLabel(item.alertDate);
    final isAlertSoon = item.alertDate != null &&
        item.alertDate!.difference(DateTime.now()).inDays <= 3 &&
        !item.isResolved;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: color, width: 4),
          top: BorderSide(color: AppColors.border),
          right: BorderSide(color: AppColors.border),
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppTextStyles.labelLarge),
                  if (item.detail != null) ...[
                    const SizedBox(height: 2),
                    Text(item.detail!, style: AppTextStyles.caption),
                  ],
                  if (item.status != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.status!,
                        style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  if (alertLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      alertLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: isAlertSoon ? const Color(0xFFF59E0B) : AppColors.textTertiary,
                        fontWeight: isAlertSoon ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (showActions)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: AppColors.textTertiary, size: 20),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) => _handleMenu(val, item),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'status',
                    child: Row(children: [
                      Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text('Update status', style: AppTextStyles.bodySmall),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'done',
                    child: Row(children: [
                      Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text('Mark done', style: AppTextStyles.bodySmall.copyWith(color: AppColors.success)),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [
                      Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text('Delete', style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                    ]),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _handleMenu(String action, WatchItem item) {
    final notifier = ref.read(watchlistProvider.notifier);
    if (action == 'done') {
      notifier.resolveItem(item.id);
    } else if (action == 'delete') {
      notifier.deleteItem(item.id);
    } else if (action == 'status') {
      _showStatusDialog(item);
    }
  }

  void _showStatusDialog(WatchItem item) {
    final ctrl = TextEditingController(text: item.status ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Update status', style: AppTextStyles.headlineSmall),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppTextStyles.bodyMedium,
          decoration: InputDecoration(
            hintText: 'e.g. Flight on time, Price: ₹1,89,900',
            hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: AppTextStyles.button.copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                ref.read(watchlistProvider.notifier).updateStatus(item.id, val);
              }
              Navigator.pop(ctx);
            },
            child: Text('Save', style: AppTextStyles.button.copyWith(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    WatchType selectedType = WatchType.flight;
    final titleCtrl = TextEditingController();
    final detailCtrl = TextEditingController();
    DateTime? alertDate;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Add to Watch List', style: AppTextStyles.headlineMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Type chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: WatchType.values.map((t) {
                    final selected = selectedType == t;
                    final color = _typeColors[t]!;
                    return GestureDetector(
                      onTap: () => setSheet(() => selectedType = t),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? color.withOpacity(0.15) : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? color : AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_typeIcons[t], size: 14, color: selected ? color : AppColors.textTertiary),
                            const SizedBox(width: 6),
                            Text(
                              _typeLabels[t]!,
                              style: AppTextStyles.labelSmall.copyWith(
                                color: selected ? color : AppColors.textSecondary,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Title (e.g. IndiGo 6E-204)',
                  hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailCtrl,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Detail (optional)',
                  hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetCtx,
                    initialDate: DateTime.now().add(const Duration(days: 1)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setSheet(() => alertDate = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_outlined, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      Text(
                        alertDate != null
                            ? 'Alert: ${alertDate!.day}/${alertDate!.month}/${alertDate!.year}'
                            : 'Set alert date (optional)',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: alertDate != null ? AppColors.textPrimary : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
                    ref.read(watchlistProvider.notifier).addItem(WatchItem(
                      id: 'w_${DateTime.now().millisecondsSinceEpoch}',
                      title: title,
                      detail: detailCtrl.text.trim().isEmpty ? null : detailCtrl.text.trim(),
                      type: selectedType,
                      alertDate: alertDate,
                      createdAt: DateTime.now(),
                    ));
                    Navigator.pop(sheetCtx);
                  },
                  child: const Text('Add to Watch List', style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
