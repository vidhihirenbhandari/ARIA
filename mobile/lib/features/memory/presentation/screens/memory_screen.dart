import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/aria_memory.dart';
import '../widgets/memory_card.dart';

// ── Structured memory categories ───────────────────────────────────────────

class _MemoryCategory {
  final String label;
  final IconData icon;
  final Color color;
  final List<_MemoryItem> items;

  const _MemoryCategory({
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
  });
}

class _MemoryItem {
  final String text;
  _MemoryItem(this.text);
}

final _structuredCategories = <_MemoryCategory>[
  _MemoryCategory(
    label: 'About Me',
    icon: Icons.person_outline,
    color: const Color(0xFF4A9EFF),
    items: [
      _MemoryItem('Works at Mantratec as a developer'),
      _MemoryItem('Prefers mornings for deep work'),
      _MemoryItem('Goal: ship ARIA to 1000 users by Q2'),
    ],
  ),
  _MemoryCategory(
    label: 'My People',
    icon: Icons.people_outline,
    color: const Color(0xFFFF7043),
    items: [
      _MemoryItem('Raj — colleague, often proposes meetings last minute'),
      _MemoryItem('Sarah — friend visiting Mumbai in December'),
      _MemoryItem('Mom — birthday January 15th'),
    ],
  ),
  _MemoryCategory(
    label: 'My Places',
    icon: Icons.place_outlined,
    color: const Color(0xFF66BB6A),
    items: [
      _MemoryItem('Office: Mantratec, Bengaluru'),
      _MemoryItem('Home: Indiranagar, Bengaluru'),
      _MemoryItem('Gym: Gold\'s, 100m from office'),
    ],
  ),
  _MemoryCategory(
    label: 'Preferences',
    icon: Icons.tune_outlined,
    color: const Color(0xFFAB47BC),
    items: [
      _MemoryItem('Prefers voice messages over long text'),
      _MemoryItem('Wants water reminders every 2 hours'),
      _MemoryItem('No meetings on Friday afternoons'),
    ],
  ),
  _MemoryCategory(
    label: 'Important Dates',
    icon: Icons.event_outlined,
    color: const Color(0xFFFFCA28),
    items: [
      _MemoryItem('Project Alpha deadline: end of Q1'),
      _MemoryItem('Mom\'s birthday: January 15th'),
      _MemoryItem('Sarah visiting Mumbai: December'),
    ],
  ),
];

// ── Screen ──────────────────────────────────────────────────────────────────

class MemoryScreen extends ConsumerStatefulWidget {
  const MemoryScreen({super.key});

  @override
  ConsumerState<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends ConsumerState<MemoryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  late TabController _tabController;

  static const List<String> _filters = [
    'All',
    'People',
    'Promises',
    'Projects',
    'Events',
  ];

  final List<AriaMemory> _memories = [
    AriaMemory(
      id: '1',
      userId: 'u1',
      content: 'You promised Raj you\'ll send the proposal by next Friday.',
      tags: ['promise', 'work'],
      peopleMentioned: ['Raj'],
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    AriaMemory(
      id: '2',
      userId: 'u1',
      content:
          'Sarah mentioned she\'s visiting Mumbai in December. Remember to plan something.',
      tags: ['personal', 'travel'],
      peopleMentioned: ['Sarah'],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AriaMemory(
      id: '3',
      userId: 'u1',
      content:
          'Project Alpha deadline is end of Q1. Team needs design mockups by week 3.',
      tags: ['project', 'work', 'deadline'],
      peopleMentioned: [],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    AriaMemory(
      id: '4',
      userId: 'u1',
      content: 'Mom\'s birthday is January 15th. Don\'t forget to order a gift.',
      tags: ['family', 'birthday'],
      peopleMentioned: ['Mom'],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];

  List<AriaMemory> get _filteredMemories {
    var result = _memories;
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((m) =>
              m.content.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    if (_selectedFilter != 'All') {
      final filter = _selectedFilter.toLowerCase();
      result = result
          .where((m) => m.tags.any((t) => t.contains(filter)))
          .toList();
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddMemorySheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.psychology_outlined,
                      color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text('Add Memory', style: AppTextStyles.headlineMedium),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Tell ARIA something important to remember.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: AppColors.textPrimary),
              maxLines: 4,
              autofocus: true,
              decoration: InputDecoration(
                hintText:
                    'e.g. "Raj\'s project deadline is March 15th" or "Sarah prefers email over calls"',
                hintStyle:
                    const TextStyle(color: AppColors.textTertiary, fontSize: 13),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final text = ctrl.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(context);
                  setState(() {
                    _memories.insert(
                      0,
                      AriaMemory(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        userId: 'u1',
                        content: text,
                        tags: ['manual'],
                        peopleMentioned: [],
                        createdAt: DateTime.now(),
                      ),
                    );
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Memory', style: AppTextStyles.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Memory', style: AppTextStyles.headlineLarge),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textTertiary,
          indicatorColor: AppColors.accent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Timeline'),
            Tab(text: 'Categories'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMemorySheet,
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label:
            const Text('Add Memory', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTimeline(),
          _buildCategories(),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildFilterChips(),
        Expanded(
          child: _filteredMemories.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: _filteredMemories.length,
                  itemBuilder: (_, i) => MemoryCard(
                    memory: _filteredMemories[i],
                    onDelete: () =>
                        setState(() => _memories.remove(_filteredMemories[i])),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCategories() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _structuredCategories.length,
      itemBuilder: (_, i) => _buildCategoryCard(_structuredCategories[i]),
    );
  }

  Widget _buildCategoryCard(_MemoryCategory cat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cat.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(cat.icon, color: cat.color, size: 20),
          ),
          title: Text(cat.label, style: AppTextStyles.bodyMedium),
          subtitle: Text(
            '${cat.items.length} items',
            style: AppTextStyles.caption,
          ),
          iconColor: AppColors.textTertiary,
          collapsedIconColor: AppColors.textTertiary,
          childrenPadding:
              const EdgeInsets.only(bottom: 8, left: 16, right: 16),
          children: cat.items.map((item) => _buildCategoryItem(item, cat.color)).toList(),
        ),
      ),
    );
  }

  Widget _buildCategoryItem(_MemoryItem item, Color color) {
    return GestureDetector(
      onTap: () {
        // Tapping a category item shows it in full
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(item.text),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.text,
                style: AppTextStyles.bodyMedium.copyWith(fontSize: 13),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: TextField(
          controller: _searchController,
          style: AppTextStyles.bodyMedium,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search your memories...',
            hintStyle: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.textTertiary),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppColors.textTertiary, size: 20),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (_, i) {
          final filter = _filters[i];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.accentGradient : null,
                color: isSelected ? null : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : AppColors.border,
                ),
              ),
              child: Text(
                filter,
                style: AppTextStyles.caption.copyWith(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.psychology_outlined,
              color: AppColors.textTertiary, size: 56),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No memories found'
                : 'Your second brain is empty',
            style: AppTextStyles.headlineSmall
                .copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 8),
          const Text(
            'ARIA will remember important things\nfrom your conversations.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddMemorySheet,
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            label: const Text('Add your first memory',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
