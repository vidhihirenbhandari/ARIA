import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/packing_item.dart';
import '../../../../shared/providers/packing_provider.dart';

class PackingScreen extends ConsumerWidget {
  const PackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(packingProvider);
    final contexts = ref.watch(activePackingContextsProvider);

    final alwaysItems = items.where((i) => i.isAlwaysBring || i.context == null).toList();
    final todayItems = items
        .where((i) => !i.isAlwaysBring && i.context != null && contexts.contains(i.context))
        .toList();

    final totalItems = alwaysItems.length + todayItems.length;
    final checkedItems = items.where((i) =>
        (i.isAlwaysBring || i.context == null || contexts.contains(i.context)) && i.checked).length;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('What to bring today', style: AppTextStyles.headlineMedium),
            Text(
              '$checkedItems of $totalItems packed',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reset',
            icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: () => ref.read(packingProvider.notifier).resetForToday(),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Context chips
          SliverToBoxAdapter(child: _ContextChips(activeContexts: contexts, ref: ref)),
          // Always section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Always', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _PackingTile(item: alwaysItems[i], ref: ref),
              childCount: alwaysItems.length,
            ),
          ),
          // Today section (only if contexts active)
          if (todayItems.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Today', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _PackingTile(item: todayItems[i], ref: ref),
                childCount: todayItems.length,
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () => _showAddSheet(context, ref),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    final emojiCtrl = TextEditingController(text: '📦');
    final nameCtrl = TextEditingController();
    bool isAlways = true;
    String selectedContext = 'rain';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Add Item', style: AppTextStyles.headlineMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: emojiCtrl,
                      maxLength: 2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      style: AppTextStyles.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Item name',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.surfaceElevated,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text('Always bring', style: AppTextStyles.labelMedium),
                  const Spacer(),
                  Switch(
                    value: isAlways,
                    activeColor: AppColors.accent,
                    onChanged: (v) => setS(() => isAlways = v),
                  ),
                ],
              ),
              if (!isAlways) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedContext,
                  dropdownColor: AppColors.surfaceElevated,
                  decoration: InputDecoration(
                    labelText: 'Show when',
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'rain',    child: Text('Rain ☂️')),
                    DropdownMenuItem(value: 'travel',  child: Text('Travel 🪪')),
                    DropdownMenuItem(value: 'longday', child: Text('Long Day 🔌')),
                    DropdownMenuItem(value: 'meeting', child: Text('Meeting 💼')),
                  ],
                  onChanged: (v) { if (v != null) setS(() => selectedContext = v); },
                ),
              ],
              const SizedBox(height: 20),
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
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final item = PackingItem(
                      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      name: name,
                      emoji: emojiCtrl.text.trim().isEmpty ? '📦' : emojiCtrl.text.trim(),
                      isAlwaysBring: isAlways,
                      context: isAlways ? null : selectedContext,
                      createdAt: DateTime.now(),
                    );
                    ref.read(packingProvider.notifier).addItem(item);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Add Item', style: AppTextStyles.button),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Context chips ─────────────────────────────────────────────────────────────

class _ContextChips extends StatelessWidget {
  final Set<String> activeContexts;
  final WidgetRef ref;

  const _ContextChips({required this.activeContexts, required this.ref});

  static const _chips = [
    ('rain',    'Rain',     '☂️'),
    ('travel',  'Travel',   '🪪'),
    ('longday', 'Long Day', '🔌'),
    ('meeting', 'Meeting',  '💼'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: _chips.map((chip) {
          final (key, label, emoji) = chip;
          final active = activeContexts.contains(key);
          return GestureDetector(
            onTap: () => ref.read(activePackingContextsProvider.notifier).toggleContext(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.accent : AppColors.border,
                ),
              ),
              child: Text(
                '$emoji $label',
                style: AppTextStyles.labelMedium.copyWith(
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Packing tile ──────────────────────────────────────────────────────────────

class _PackingTile extends StatelessWidget {
  final PackingItem item;
  final WidgetRef ref;

  const _PackingTile({required this.item, required this.ref});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _confirmDelete(context),
      child: AnimatedOpacity(
        opacity: item.checked ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Text(item.emoji, style: const TextStyle(fontSize: 24)),
            title: Text(
              item.name,
              style: AppTextStyles.labelLarge.copyWith(
                decoration: item.checked ? TextDecoration.lineThrough : null,
                color: item.checked ? AppColors.textTertiary : AppColors.textPrimary,
              ),
            ),
            trailing: GestureDetector(
              onTap: () => ref.read(packingProvider.notifier).toggleChecked(item.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: item.checked ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.checked ? AppColors.accent : AppColors.border,
                    width: 2,
                  ),
                ),
                child: item.checked
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Remove "${item.name}"?', style: AppTextStyles.headlineSmall),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(packingProvider.notifier).deleteItem(item.id);
              Navigator.pop(ctx);
            },
            child: Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
