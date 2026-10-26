import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/aria_color_scheme.dart';
import '../../../../shared/models/expense.dart';
import '../../../../shared/providers/expenses_provider.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../../../../shared/services/local_storage.dart';

const _categoryColors = {
  'food':          Color(0xFFE8803A),
  'transport':     Color(0xFF3A7BD5),
  'shopping':      Color(0xFF8B5CF6),
  'entertainment': Color(0xFFEC4899),
  'health':        Color(0xFF10B981),
  'bills':         Color(0xFFEF4444),
  'other':         Color(0xFF6B7280),
};

const _categoryIcons = {
  'food':          Icons.restaurant_outlined,
  'transport':     Icons.directions_car_outlined,
  'shopping':      Icons.shopping_bag_outlined,
  'entertainment': Icons.movie_outlined,
  'health':        Icons.favorite_border_rounded,
  'bills':         Icons.receipt_long_outlined,
  'other':         Icons.category_outlined,
};

const _categoryLabels = {
  'food':          'Food',
  'transport':     'Transport',
  'shopping':      'Shopping',
  'entertainment': 'Entertainment',
  'health':        'Health',
  'bills':         'Bills',
  'other':         'Other',
};

const _paymentApps = [
  _PaymentAppDef(key: 'googlepay', name: 'Google Pay', icon: Icons.account_balance_wallet_rounded, color: Color(0xFF4285F4)),
  _PaymentAppDef(key: 'phonepe',   name: 'PhonePe',   icon: Icons.phone_android_rounded,          color: Color(0xFF5F259F)),
  _PaymentAppDef(key: 'paytm',     name: 'Paytm',     icon: Icons.payment_rounded,                color: Color(0xFF00BAF2)),
];

final _sampleTransactions = [
  {'title': 'Swiggy',       'amount': 349.0,  'category': 'food'},
  {'title': 'Uber',         'amount': 185.0,  'category': 'transport'},
  {'title': 'Zepto',        'amount': 512.0,  'category': 'food'},
  {'title': 'BookMyShow',   'amount': 650.0,  'category': 'entertainment'},
  {'title': 'Zomato',       'amount': 298.0,  'category': 'food'},
  {'title': 'Rapido',       'amount': 55.0,   'category': 'transport'},
  {'title': 'BigBasket',    'amount': 1240.0, 'category': 'food'},
  {'title': 'Myntra',       'amount': 899.0,  'category': 'shopping'},
  {'title': 'Nykaa',        'amount': 450.0,  'category': 'shopping'},
  {'title': 'Netflix',      'amount': 649.0,  'category': 'entertainment'},
];

const double _monthlyBudget = 50000.0;

class _PaymentAppDef {
  final String key;
  final String name;
  final IconData icon;
  final Color color;
  const _PaymentAppDef({required this.key, required this.name, required this.icon, required this.color});
}

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, bool> _connectedApps = {'googlepay': false, 'phonepe': false, 'paytm': false};

  static const _months = ['January','February','March','April','May','June','July','August','September','October','November','December'];

  @override
  void initState() {
    super.initState();
    _loadConnectedApps();
  }

  void _loadConnectedApps() {
    final storage = ref.read(localStorageProvider);
    final raw = storage.get('payment_apps');
    if (raw is Map) {
      setState(() {
        _connectedApps = {
          'googlepay': raw['googlepay'] as bool? ?? false,
          'phonepe':   raw['phonepe']   as bool? ?? false,
          'paytm':     raw['paytm']     as bool? ?? false,
        };
      });
    }
  }

  Future<void> _saveConnectedApps() async {
    await ref.read(localStorageProvider).put('payment_apps', _connectedApps);
  }

  List<Expense> _monthExpenses(List<Expense> all) => all
      .where((e) => e.date.year == _viewMonth.year && e.date.month == _viewMonth.month)
      .toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  Map<String, double> _categoryTotals(List<Expense> expenses) {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _viewMonth.year == now.year && _viewMonth.month == now.month;
  }

  void _importTransactions(String appKey) {
    final now = DateTime.now();
    final startIdx = appKey.hashCode.abs() % _sampleTransactions.length;
    final toImport = List.generate(3, (i) => _sampleTransactions[(startIdx + i) % _sampleTransactions.length]);
    for (int i = 0; i < toImport.length; i++) {
      final t = toImport[i];
      ref.read(expensesProvider.notifier).addExpense(Expense(
        id: 'imp_${DateTime.now().millisecondsSinceEpoch}_$i',
        title: t['title'] as String,
        amount: t['amount'] as double,
        category: t['category'] as String,
        date: now.subtract(Duration(days: (i + 1) * 2)),
        note: 'Imported from ${_paymentApps.firstWhere((a) => a.key == appKey).name}',
        createdAt: now,
      ));
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('3 transactions imported'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final themeIndex = ref.watch(themeIndexProvider);
    final scheme = AriaColorScheme.presets[themeIndex.clamp(0, AriaColorScheme.presets.length - 1)];
    final all = ref.watch(expensesProvider);
    final expenses = _monthExpenses(all);
    final catTotals = _categoryTotals(expenses);
    final totalSpent = expenses.fold(0.0, (s, e) => s + e.amount);
    final remaining = _monthlyBudget - totalSpent;
    final progress = (totalSpent / _monthlyBudget).clamp(0.0, 1.0);
    final fmt = NumberFormat('#,##,##0', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Expenses', style: AppTextStyles.headlineLarge),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: AppColors.accent),
            onPressed: () => _showAddExpenseSheet(scheme),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Month navigator
          _buildMonthNav(scheme),
          // Budget card
          _buildBudgetCard(scheme, totalSpent, remaining, progress, fmt),
          const SizedBox(height: 20),
          // Spending by Category
          if (catTotals.isNotEmpty) ...[
            _buildSectionHeader('Spending by Category'),
            _buildDonutSection(catTotals, totalSpent, fmt),
            const SizedBox(height: 20),
          ],
          // Spending Breakdown
          _buildSectionHeader('Spending Breakdown'),
          if (expenses.isEmpty)
            _buildEmpty()
          else
            ...expenses.map((e) => _buildExpenseTile(e, fmt)),
          const SizedBox(height: 24),
          // Connected accounts
          _buildSectionHeader('Connected Accounts'),
          _buildConnectedAccounts(),
        ],
      ),
    );
  }

  Widget _buildMonthNav(AriaColorScheme scheme) {
    final now = DateTime.now();
    final label = '${_months[_viewMonth.month - 1]} ${_viewMonth.year}';
    final sublabel = _isCurrentMonth ? 'This Month' : DateFormat('MMMM yyyy').format(_viewMonth);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded, color: scheme.accent),
            onPressed: () => setState(() =>
                _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1)),
          ),
          Expanded(
            child: Column(
              children: [
                Text(label, style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
                Text(
                  _isCurrentMonth ? 'This Month' : sublabel,
                  style: AppTextStyles.caption.copyWith(color: scheme.accent),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: _viewMonth.year == now.year && _viewMonth.month == now.month
                  ? AppColors.textTertiary
                  : scheme.accent,
            ),
            onPressed: _viewMonth.year == now.year && _viewMonth.month == now.month
                ? null
                : () => setState(() =>
                    _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(AriaColorScheme scheme, double spent, double remaining, double progress, NumberFormat fmt) {
    final overBudget = spent > _monthlyBudget;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Monthly Budget', style: AppTextStyles.headlineSmall),
                    const SizedBox(height: 2),
                    Text(
                      overBudget
                          ? '₹${fmt.format(spent - _monthlyBudget)} over budget'
                          : '₹${fmt.format(remaining)} remaining',
                      style: AppTextStyles.caption.copyWith(
                        color: overBudget ? AppColors.error : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '₹${fmt.format(_monthlyBudget)}',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                overBudget ? AppColors.error : scheme.accent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.arrow_upward_rounded,
                  size: 14,
                  color: overBudget ? AppColors.error : scheme.accent),
              const SizedBox(width: 4),
              Text(
                '₹${fmt.format(spent)} spent',
                style: AppTextStyles.caption.copyWith(
                  color: overBudget ? AppColors.error : scheme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% used',
                style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonutSection(Map<String, double> catTotals, double total, NumberFormat fmt) {
    final sorted = catTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Donut chart
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: _DonutPainter(catTotals, total),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${fmt.format(total)}',
                        style: AppTextStyles.labelSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        'total',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Legend
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sorted.take(6).map((entry) {
                  final color = _categoryColors[entry.key] ?? const Color(0xFF6B7280);
                  final pct = total > 0 ? (entry.value / total * 100).toStringAsFixed(0) : '0';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _categoryLabels[entry.key] ?? entry.key,
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                        Text(
                          '₹${fmt.format(entry.value)}',
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(title, style: AppTextStyles.headlineSmall),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'No expenses this month',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap + to log one or connect a payment app',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense, NumberFormat fmt) {
    final color = _categoryColors[expense.category] ?? const Color(0xFF6B7280);
    final icon  = _categoryIcons[expense.category] ?? Icons.category_outlined;
    final label = _categoryLabels[expense.category] ?? expense.category;

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Delete expense?', style: AppTextStyles.headlineSmall),
          content: Text('Remove "${expense.title}"?', style: AppTextStyles.bodySmall),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete', style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
      onDismissed: (_) => ref.read(expensesProvider.notifier).deleteExpense(expense.id),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.title,
                      style: AppTextStyles.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(label,
                      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${fmt.format(expense.amount)}',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM').format(expense.date),
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedAccounts() {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        itemCount: _paymentApps.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final app = _paymentApps[i];
          final connected = _connectedApps[app.key] ?? false;
          return GestureDetector(
            onTap: connected
                ? () => _importTransactions(app.key)
                : () => _showConnectSheet(app),
            child: Container(
              width: 130,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: connected ? app.color.withOpacity(0.4) : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(app.icon, color: app.color, size: 20),
                      const Spacer(),
                      if (connected)
                        Container(width: 8, height: 8,
                            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                    ],
                  ),
                  Text(app.name, style: AppTextStyles.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: connected ? app.color.withOpacity(0.1) : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: connected ? null : Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      connected ? 'Import' : 'Connect',
                      style: AppTextStyles.caption.copyWith(
                        color: connected ? app.color : AppColors.textSecondary,
                        fontWeight: connected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showConnectSheet(_PaymentAppDef app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(color: app.color.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
              child: Icon(app.icon, color: app.color, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Connect ${app.name}', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'ARIA will read your transaction history to auto-log expenses. This is a demo — no real data is accessed.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: app.color, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() => _connectedApps[app.key] = true);
                  _saveConnectedApps();
                  _importTransactions(app.key);
                },
                child: Text('Connect', style: AppTextStyles.button.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddExpenseSheet(AriaColorScheme scheme) {
    final titleCtrl  = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl   = TextEditingController();
    String selectedCategory = 'food';
    DateTime selectedDate   = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Add Expense', style: AppTextStyles.headlineMedium),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 16),
              _field(titleCtrl, 'Title'),
              const SizedBox(height: 12),
              _field(amountCtrl, 'Amount (₹)', keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: _fieldDeco('Category'),
                items: Expense.categories.map((c) => DropdownMenuItem(value: c, child: Text(_catLabel(c)))).toList(),
                onChanged: (v) { if (v != null) setS(() => selectedCategory = v); },
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx, initialDate: selectedDate,
                    firstDate: DateTime(2020), lastDate: DateTime.now(),
                  );
                  if (p != null) setS(() => selectedDate = p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.background, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(children: [
                    Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Text(DateFormat('dd MMM yyyy').format(selectedDate), style: AppTextStyles.bodyMedium),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              _field(noteCtrl, 'Note (optional)', maxLines: 2),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.accent, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    final amount = double.tryParse(amountCtrl.text.trim());
                    if (title.isEmpty || amount == null || amount <= 0) return;
                    ref.read(expensesProvider.notifier).addExpense(Expense(
                      id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
                      title: title, amount: amount, category: selectedCategory,
                      date: selectedDate,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                      createdAt: DateTime.now(),
                    ));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add Expense', style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _fieldDeco(label),
    );
  }

  InputDecoration _fieldDeco(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.accent, width: 2)),
  );

  String _catLabel(String c) => _categoryLabels[c] ?? (c[0].toUpperCase() + c.substring(1));
}

// ── Donut chart painter ────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final Map<String, double> totals;
  final double total;

  _DonutPainter(this.totals, this.total);

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2;
    final innerR = outerR * 0.60;
    final rect = Rect.fromCircle(center: center, radius: outerR);

    final sorted = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    double startAngle = -math.pi / 2;
    const gap = 0.03;

    for (final entry in sorted) {
      final sweep = (entry.value / total) * 2 * math.pi - gap;
      if (sweep <= 0) continue;
      final color = _categoryColors[entry.key] ?? const Color(0xFF6B7280);
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerR - innerR
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (outerR + innerR) / 2),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.totals != totals || old.total != total;
}
