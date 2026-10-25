import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/expense.dart';
import '../../../../shared/providers/expenses_provider.dart';
import '../../../../shared/services/local_storage.dart';

// Category colours
const _categoryColors = {
  'food': Color(0xFFE8803A),
  'transport': Color(0xFF3A7BD5),
  'shopping': Color(0xFF8B5CF6),
  'entertainment': Color(0xFFEC4899),
  'health': Color(0xFF10B981),
  'bills': Color(0xFFEF4444),
  'other': Color(0xFF6B7280),
};

// Category icons
const _categoryIcons = {
  'food': Icons.restaurant_outlined,
  'transport': Icons.directions_car_outlined,
  'shopping': Icons.shopping_bag_outlined,
  'entertainment': Icons.movie_outlined,
  'health': Icons.favorite_border_rounded,
  'bills': Icons.receipt_long_outlined,
  'other': Icons.category_outlined,
};

// Payment app definitions
const _paymentApps = [
  _PaymentAppDef(
    key: 'googlepay',
    name: 'Google Pay',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF4285F4),
  ),
  _PaymentAppDef(
    key: 'phonepe',
    name: 'PhonePe',
    icon: Icons.phone_android_rounded,
    color: Color(0xFF5F259F),
  ),
  _PaymentAppDef(
    key: 'paytm',
    name: 'Paytm',
    icon: Icons.payment_rounded,
    color: Color(0xFF00BAF2),
  ),
];

// Sample transactions to import
final _sampleTransactions = [
  {'title': 'Swiggy', 'amount': 349.0, 'category': 'food'},
  {'title': 'Uber', 'amount': 185.0, 'category': 'transport'},
  {'title': 'Zepto', 'amount': 512.0, 'category': 'food'},
  {'title': 'BookMyShow', 'amount': 650.0, 'category': 'entertainment'},
  {'title': 'Zomato', 'amount': 298.0, 'category': 'food'},
  {'title': 'Rapido', 'amount': 55.0, 'category': 'transport'},
  {'title': 'BigBasket', 'amount': 1240.0, 'category': 'food'},
  {'title': 'Myntra', 'amount': 899.0, 'category': 'shopping'},
  {'title': 'Nykaa', 'amount': 450.0, 'category': 'shopping'},
  {'title': 'Netflix', 'amount': 649.0, 'category': 'entertainment'},
];

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
  String _activeFilter = 'All';
  String? _activeCategory;
  Map<String, bool> _connectedApps = {
    'googlepay': false,
    'phonepe': false,
    'paytm': false,
  };

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
          'phonepe': raw['phonepe'] as bool? ?? false,
          'paytm': raw['paytm'] as bool? ?? false,
        };
      });
    }
  }

  Future<void> _saveConnectedApps() async {
    final storage = ref.read(localStorageProvider);
    await storage.put('payment_apps', _connectedApps);
  }

  List<String> get _filterChips => ['All', 'This Week', 'This Month'];

  List<Expense> _applyFilters(List<Expense> expenses) {
    final now = DateTime.now();
    List<Expense> filtered = expenses;

    if (_activeFilter == 'This Week') {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      filtered = filtered
          .where((e) => e.date.isAfter(weekStart.subtract(const Duration(days: 1))))
          .toList();
    } else if (_activeFilter == 'This Month') {
      filtered = filtered
          .where((e) => e.date.year == now.year && e.date.month == now.month)
          .toList();
    }

    if (_activeCategory != null) {
      filtered = filtered.where((e) => e.category == _activeCategory).toList();
    }

    return filtered;
  }

  void _importTransactions(String appKey) {
    final now = DateTime.now();
    // Pick 3 random-ish transactions based on appKey hash
    final startIdx = appKey.hashCode.abs() % _sampleTransactions.length;
    final toImport = List.generate(3, (i) => _sampleTransactions[(startIdx + i) % _sampleTransactions.length]);

    for (final t in toImport) {
      final daysAgo = (toImport.indexOf(t) + 1) * 2;
      ref.read(expensesProvider.notifier).addExpense(Expense(
        id: 'imp_${DateTime.now().millisecondsSinceEpoch}_$i${toImport.indexOf(t)}',
        title: t['title'] as String,
        amount: t['amount'] as double,
        category: t['category'] as String,
        date: now.subtract(Duration(days: daysAgo)),
        note: 'Imported from ${_paymentApps.firstWhere((a) => a.key == appKey).name}',
        createdAt: now,
      ));
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('3 transactions imported'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showConnectSheet(_PaymentAppDef app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: app.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
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
                  backgroundColor: app.color,
                  foregroundColor: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final notifier = ref.read(expensesProvider.notifier);
    final filtered = _applyFilters(expenses);
    final rupeeFmt = NumberFormat('#,##,##0.00', 'en_IN');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Expenses', style: AppTextStyles.headlineLarge),
        centerTitle: false,
      ),
      body: CustomScrollView(
        slivers: [
          // Connected accounts section
          SliverToBoxAdapter(child: _buildConnectedAccounts()),
          // Summary card
          SliverToBoxAdapter(child: _buildSummaryCard(notifier, rupeeFmt)),
          // Filter chips
          SliverToBoxAdapter(child: _buildFilterChips()),
          // Expense list or empty state
          filtered.isEmpty
              ? SliverFillRemaining(child: _buildEmptyState())
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final expense = filtered[index];
                      return _buildExpenseTile(expense, rupeeFmt);
                    },
                    childCount: filtered.length,
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        tooltip: 'Add manually',
        onPressed: () => _showAddExpenseSheet(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildConnectedAccounts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            'Connected Accounts',
            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            itemCount: _paymentApps.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final app = _paymentApps[index];
              final isConnected = _connectedApps[app.key] ?? false;
              return _buildPaymentAppCard(app, isConnected);
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPaymentAppCard(_PaymentAppDef app, bool isConnected) {
    return GestureDetector(
      onTap: isConnected ? () => _importTransactions(app.key) : () => _showConnectSheet(app),
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isConnected ? app.color.withOpacity(0.4) : AppColors.border,
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
                if (isConnected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              app.name,
              style: AppTextStyles.labelMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (isConnected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: app.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Import',
                  style: AppTextStyles.caption.copyWith(
                    color: app.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Connect',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ExpensesNotifier notifier, NumberFormat fmt) {
    final total = notifier.totalThisMonth();

    // Top 3 categories by total this month
    final monthExpenses = notifier.expensesThisMonth();
    final catTotals = <String, double>{};
    for (final e in monthExpenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final topCategories = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = topCategories.take(3).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Spent this month',
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            '₹${fmt.format(total)}',
            style: AppTextStyles.displayMedium.copyWith(color: Colors.white),
          ),
          if (top3.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: top3.map((entry) {
                final color = _categoryColors[entry.key] ?? const Color(0xFF6B7280);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _capitalize(entry.key),
                          style: AppTextStyles.labelSmall.copyWith(color: Colors.white70),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '₹${fmt.format(entry.value)}',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          ..._filterChips.map((f) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(f),
                  selected: _activeFilter == f,
                  onSelected: (_) => setState(() {
                    _activeFilter = f;
                  }),
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.accent,
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: _activeFilter == f ? Colors.white : AppColors.textSecondary,
                  ),
                  checkmarkColor: Colors.white,
                  side: BorderSide(
                    color: _activeFilter == f ? AppColors.accent : AppColors.border,
                  ),
                ),
              )),
          const SizedBox(width: 4),
          ...Expense.categories.map((cat) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(_capitalize(cat)),
                  selected: _activeCategory == cat,
                  onSelected: (_) => setState(() {
                    _activeCategory = _activeCategory == cat ? null : cat;
                  }),
                  backgroundColor: AppColors.surface,
                  selectedColor:
                      (_categoryColors[cat] ?? AppColors.accent).withOpacity(0.15),
                  labelStyle: AppTextStyles.labelMedium.copyWith(
                    color: _activeCategory == cat
                        ? (_categoryColors[cat] ?? AppColors.accent)
                        : AppColors.textSecondary,
                  ),
                  checkmarkColor: _categoryColors[cat] ?? AppColors.accent,
                  side: BorderSide(
                    color: _activeCategory == cat
                        ? (_categoryColors[cat] ?? AppColors.accent)
                        : AppColors.border,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(Expense expense, NumberFormat fmt) {
    final color = _categoryColors[expense.category] ?? const Color(0xFF6B7280);
    final icon = _categoryIcons[expense.category] ?? Icons.category_outlined;

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
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Delete expense?', style: AppTextStyles.headlineSmall),
            content: Text(
              'This will permanently remove "${expense.title}".',
              style: AppTextStyles.bodySmall,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Delete', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(expensesProvider.notifier).deleteExpense(expense.id);
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            expense.title,
            style: AppTextStyles.labelLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                DateFormat('dd MMM yyyy').format(expense.date),
                style: AppTextStyles.caption,
              ),
              if (expense.note != null && expense.note!.isNotEmpty)
                Text(
                  expense.note!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: Text(
            '₹${fmt.format(expense.amount)}',
            style: AppTextStyles.headlineSmall.copyWith(color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 36,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No expenses yet',
            style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Connect a payment app or tap + to add manually',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showAddExpenseSheet(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String selectedCategory = 'food';
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Add Expense', style: AppTextStyles.headlineMedium),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                    items: Expense.categories
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(_capitalize(cat)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: sheetCtx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setSheetState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 18, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('dd MMM yyyy').format(selectedDate),
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        final title = titleCtrl.text.trim();
                        final amountText = amountCtrl.text.trim();
                        if (title.isEmpty || amountText.isEmpty) return;
                        final amount = double.tryParse(amountText);
                        if (amount == null || amount <= 0) return;

                        final expense = Expense(
                          id: 'exp_${DateTime.now().millisecondsSinceEpoch}',
                          title: title,
                          amount: amount,
                          category: selectedCategory,
                          date: selectedDate,
                          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                          createdAt: DateTime.now(),
                        );
                        ref.read(expensesProvider.notifier).addExpense(expense);
                        Navigator.pop(sheetCtx);
                      },
                      child: const Text('Add Expense', style: AppTextStyles.button),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
