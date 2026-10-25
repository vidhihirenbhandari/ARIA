import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/expense.dart';
import '../../../../shared/providers/expenses_provider.dart';

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

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _activeFilter = 'All';
  String? _activeCategory;

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
        onPressed: () => _showAddExpenseSheet(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
            'Tap + to record your first expense',
            style: AppTextStyles.bodySmall,
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
