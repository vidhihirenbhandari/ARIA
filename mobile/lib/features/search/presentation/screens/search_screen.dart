import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/providers/commitments_provider.dart';
import '../../../../shared/providers/people_provider.dart';
import '../../../../shared/providers/subscriptions_provider.dart';
import '../../../../shared/services/local_storage.dart';

// ── Result model ───────────────────────────────────────────────────────────────

enum _ResultType { commitment, person, subscription }

class _SearchResult {
  final _ResultType type;
  final String id;
  final String title;
  final String subtitle;

  _SearchResult({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
  });
}

// ── Search screen ──────────────────────────────────────────────────────────────

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  List<String> _recentSearches = [];

  static const _recentKey = 'recent_searches';

  @override
  void initState() {
    super.initState();
    _loadRecent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _controller.addListener(() {
      setState(() => _query = _controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Storage helpers ──────────────────────────────────────────────────────────

  void _loadRecent() {
    final storage = ref.read(localStorageProvider);
    final raw = storage.get(_recentKey);
    if (raw is List) {
      setState(() => _recentSearches = List<String>.from(raw));
    }
  }

  Future<void> _saveSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    final storage = ref.read(localStorageProvider);
    final updated = [q, ..._recentSearches.where((s) => s != q)].take(5).toList();
    await storage.put(_recentKey, updated);
    setState(() => _recentSearches = updated);
  }

  Future<void> _removeRecent(String query) async {
    final storage = ref.read(localStorageProvider);
    final updated = _recentSearches.where((s) => s != query).toList();
    await storage.put(_recentKey, updated);
    setState(() => _recentSearches = updated);
  }

  // ── Search logic ─────────────────────────────────────────────────────────────

  List<_SearchResult> _runSearch(String q) {
    if (q.trim().isEmpty) return [];
    final lower = q.toLowerCase();
    final results = <_SearchResult>[];

    // Commitments — match on text and person
    for (final c in ref.read(commitmentsProvider)) {
      if (c.text.toLowerCase().contains(lower) ||
          c.person.toLowerCase().contains(lower)) {
        final due = c.dueDate != null ? _fmtDate(c.dueDate!) : 'No due date';
        final personPart = c.person.isNotEmpty ? '${c.person} · ' : '';
        results.add(_SearchResult(
          type: _ResultType.commitment,
          id: c.id,
          title: c.text,
          subtitle: '$personPart$due',
        ));
      }
    }

    // People — match on name, notes, relationship
    for (final p in ref.read(peopleProvider)) {
      if (p.name.toLowerCase().contains(lower) ||
          p.notes.toLowerCase().contains(lower) ||
          p.relationship.toLowerCase().contains(lower)) {
        final rel = _capitalize(p.relationship);
        final noteSnip = p.notes.isNotEmpty
            ? ' · ${p.notes.length > 40 ? "${p.notes.substring(0, 40)}…" : p.notes}'
            : '';
        results.add(_SearchResult(
          type: _ResultType.person,
          id: p.id,
          title: p.name,
          subtitle: '$rel$noteSnip',
        ));
      }
    }

    // Subscriptions — match on name, category, notes
    for (final s in ref.read(subscriptionsProvider)) {
      if (s.name.toLowerCase().contains(lower) ||
          s.category.toLowerCase().contains(lower) ||
          (s.notes?.toLowerCase().contains(lower) ?? false)) {
        results.add(_SearchResult(
          type: _ResultType.subscription,
          id: s.id,
          title: s.name,
          subtitle: '${_capitalize(s.category)} · Renews ${_fmtDate(s.nextRenewalDate)}',
        ));
      }
    }

    return results;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _fmtDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(date.year, date.month, date.day).difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < 0) return '${-diff}d overdue';
    if (diff < 7) return 'In ${diff}d';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  void _onResultTap(_SearchResult result) {
    _saveSearch(_query);
    switch (result.type) {
      case _ResultType.commitment:
        context.go('/home/tasks');
      case _ResultType.person:
        context.go('/home/people');
      case _ResultType.subscription:
        context.go('/home/renewals');
    }
  }

  void _onRecentTap(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
  }

  void _clearQuery() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final results = _runSearch(_query);
    final commitments = results.where((r) => r.type == _ResultType.commitment).toList();
    final people = results.where((r) => r.type == _ResultType.person).toList();
    final subs = results.where((r) => r.type == _ResultType.subscription).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _query.isEmpty
                  ? _buildEmptyState()
                  : results.isEmpty
                      ? _buildNoResults()
                      : _buildResults(commitments, people, subs),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.go('/home/dashboard'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Search field
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: AppTextStyles.bodyMedium,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search commitments, people, subs…',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) _saveSearch(v.trim());
                      },
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: _clearQuery,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.textTertiary,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty state (recent searches) ────────────────────────────────────────────

  Widget _buildEmptyState() {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 52, color: AppColors.textTertiary),
            const SizedBox(height: 14),
            Text('Search everything', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 6),
            Text(
              'Commitments, people & subscriptions',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          'RECENT SEARCHES',
          style: AppTextStyles.labelSmall.copyWith(letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),
        ..._recentSearches.map((q) => _RecentTile(
              query: q,
              onTap: () => _onRecentTap(q),
              onRemove: () => _removeRecent(q),
            )),
      ],
    );
  }

  // ── No results ───────────────────────────────────────────────────────────────

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 52, color: AppColors.textTertiary),
          const SizedBox(height: 14),
          Text('No results for "$_query"', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 6),
          Text('Try a different search term', style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }

  // ── Results grouped by type ──────────────────────────────────────────────────

  Widget _buildResults(
    List<_SearchResult> commitments,
    List<_SearchResult> people,
    List<_SearchResult> subs,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (commitments.isNotEmpty) ...[
          _SectionHeader(label: 'Commitments', count: commitments.length),
          const SizedBox(height: 8),
          ...commitments.map((r) => _ResultTile(
                result: r,
                icon: Icons.task_alt_rounded,
                iconColor: AppColors.accent,
                onTap: () => _onResultTap(r),
              )),
          const SizedBox(height: 20),
        ],
        if (people.isNotEmpty) ...[
          _SectionHeader(label: 'People', count: people.length),
          const SizedBox(height: 8),
          ...people.map((r) => _ResultTile(
                result: r,
                icon: Icons.person_rounded,
                iconColor: AppColors.secondary,
                onTap: () => _onResultTap(r),
              )),
          const SizedBox(height: 20),
        ],
        if (subs.isNotEmpty) ...[
          _SectionHeader(label: 'Subscriptions', count: subs.length),
          const SizedBox(height: 8),
          ...subs.map((r) => _ResultTile(
                result: r,
                icon: Icons.autorenew_rounded,
                iconColor: AppColors.warning,
                onTap: () => _onResultTap(r),
              )),
        ],
      ],
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTextStyles.labelSmall.copyWith(letterSpacing: 0.8),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count', style: AppTextStyles.labelSmall),
        ),
      ],
    );
  }
}

// ── Result tile ────────────────────────────────────────────────────────────────

class _ResultTile extends StatelessWidget {
  final _SearchResult result;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  const _ResultTile({
    required this.result,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.subtitle,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Recent search tile ─────────────────────────────────────────────────────────

class _RecentTile extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _RecentTile({
    required this.query,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Icon(Icons.history_rounded, color: AppColors.textTertiary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(query, style: AppTextStyles.bodyMedium),
            ),
            GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.close_rounded, color: AppColors.textTertiary, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
