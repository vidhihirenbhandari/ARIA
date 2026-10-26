import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/commitment.dart';
import '../../../../shared/providers/commitments_provider.dart';
import '../../../../shared/services/claude_service.dart';
import '../../../../shared/services/local_storage.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  final TextEditingController _inputController = TextEditingController();
  bool _isLoading = false;
  Map<String, dynamic>? _extractedResults;
  Map<String, bool> _selectedItems = {};
  List<Map<String, dynamic>> _inboxHistory = [];

  static const _historyKey = 'inbox_history';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _loadHistory() {
    final storage = ref.read(localStorageProvider);
    final raw = storage.getList(_historyKey);
    setState(() {
      _inboxHistory = raw;
    });
  }

  Future<void> _saveToHistory(String text, Map<String, dynamic> results) async {
    final storage = ref.read(localStorageProvider);
    final entry = {
      'text': text.length > 100 ? '${text.substring(0, 100)}…' : text,
      'timestamp': DateTime.now().toIso8601String(),
      'commitments_count': (results['commitments'] as List?)?.length ?? 0,
      'tasks_count': (results['tasks'] as List?)?.length ?? 0,
      'events_count': (results['events'] as List?)?.length ?? 0,
    };
    final updated = [entry, ..._inboxHistory].take(5).toList();
    await storage.putList(_historyKey, updated);
    setState(() => _inboxHistory = updated);
  }

  Future<void> _extractInsights() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _extractedResults = null;
      _selectedItems = {};
    });

    try {
      final claudeService = ref.read(claudeServiceProvider);
      final results = await claudeService.extractInsights(text);

      // Pre-select all items
      final selected = <String, bool>{};
      final commitments = results['commitments'] as List? ?? [];
      final tasks = results['tasks'] as List? ?? [];
      final events = results['events'] as List? ?? [];
      final people = results['people'] as List? ?? [];

      for (int i = 0; i < commitments.length; i++) {
        selected['commitment_$i'] = true;
      }
      for (int i = 0; i < tasks.length; i++) {
        selected['task_$i'] = true;
      }
      for (int i = 0; i < events.length; i++) {
        selected['event_$i'] = true;
      }
      for (int i = 0; i < people.length; i++) {
        selected['person_$i'] = true;
      }

      await _saveToHistory(text, results);

      setState(() {
        _extractedResults = results;
        _selectedItems = selected;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not extract insights: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveSelected() async {
    if (_extractedResults == null) return;

    final commitmentsNotifier = ref.read(commitmentsProvider.notifier);
    final commitments = _extractedResults!['commitments'] as List? ?? [];

    for (int i = 0; i < commitments.length; i++) {
      if (_selectedItems['commitment_$i'] == true) {
        final c = commitments[i] as Map<String, dynamic>;
        DateTime? dueDate;
        if (c['dueDate'] != null && c['dueDate'] != 'null') {
          try {
            dueDate = DateTime.parse(c['dueDate'] as String);
          } catch (_) {}
        }
        await commitmentsNotifier.addCommitment(Commitment(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
          text: c['text'] as String? ?? '',
          person: c['person'] as String? ?? '',
          direction: c['direction'] as String? ?? 'i_promised',
          dueDate: dueDate,
          createdAt: DateTime.now(),
          source: 'inbox',
        ));
      }
    }

    // Tasks — for now we just show a confirmation; full task provider integration
    // would use tasksProvider when it exists as a StateNotifierProvider
    final tasks = _extractedResults!['tasks'] as List? ?? [];
    int savedTaskCount = 0;
    for (int i = 0; i < tasks.length; i++) {
      if (_selectedItems['task_$i'] == true) savedTaskCount++;
    }

    setState(() {
      _extractedResults = null;
      _selectedItems = {};
      _inputController.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to ARIA. Commitments tracked.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inbox', style: AppTextStyles.headlineLarge),
            Text(
              'Paste any message to extract actions',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            ),
          ],
        ),
        toolbarHeight: 64,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInputArea(),
            const SizedBox(height: 16),
            _buildExtractButton(),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              _buildLoadingState(),
            ],
            if (_extractedResults != null) ...[
              const SizedBox(height: 24),
              _buildResultsSection(),
            ],
            const SizedBox(height: 24),
            _buildHistorySection(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: _inputController,
        maxLines: 6,
        minLines: 4,
        style: AppTextStyles.bodyMedium,
        decoration: InputDecoration(
          hintText: 'Paste a WhatsApp message, email, or any conversation...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildExtractButton() {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.accentGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _extractInsights,
          icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
          label: const Text('Extract with ARIA', style: AppTextStyles.button),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'ARIA is reading your message...',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    final results = _extractedResults!;
    final commitments = results['commitments'] as List? ?? [];
    final tasks = results['tasks'] as List? ?? [];
    final events = results['events'] as List? ?? [];
    final people = results['people'] as List? ?? [];
    final totalItems = commitments.length + tasks.length + events.length + people.length;

    if (totalItems == 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: AppColors.textTertiary, size: 40),
            const SizedBox(height: 12),
            Text(
              'No actionable items found',
              style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'Try pasting a message with commitments, tasks, or events.',
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ARIA found ${totalItems} item${totalItems == 1 ? '' : 's'}', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 12),
        if (commitments.isNotEmpty)
          _buildResultCategory(
            icon: Icons.handshake_outlined,
            color: AppColors.accent,
            title: 'Commitments',
            items: commitments.asMap().entries.map((e) {
              final c = e.value as Map<String, dynamic>;
              final dir = c['direction'] as String? ?? 'i_promised';
              return _ResultItem(
                key: 'commitment_${e.key}',
                title: c['text'] as String? ?? '',
                subtitle: '${dir == 'i_promised' ? 'You promised' : '${c['person']} promised'} · ${c['person']}${c['dueDate'] != null && c['dueDate'] != 'null' ? ' · Due ${c['dueDate']}' : ''}',
              );
            }).toList(),
          ),
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildResultCategory(
            icon: Icons.task_outlined,
            color: AppColors.success,
            title: 'Tasks',
            items: tasks.asMap().entries.map((e) {
              final t = e.value as Map<String, dynamic>;
              return _ResultItem(
                key: 'task_${e.key}',
                title: t['title'] as String? ?? '',
                subtitle: 'Priority: ${t['priority'] ?? 'medium'}${t['dueDate'] != null && t['dueDate'] != 'null' ? ' · Due ${t['dueDate']}' : ''}',
              );
            }).toList(),
          ),
        ],
        if (events.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildResultCategory(
            icon: Icons.event_outlined,
            color: AppColors.secondary,
            title: 'Events',
            items: events.asMap().entries.map((e) {
              final ev = e.value as Map<String, dynamic>;
              return _ResultItem(
                key: 'event_${e.key}',
                title: ev['title'] as String? ?? '',
                subtitle: ev['dateHint'] as String? ?? '',
              );
            }).toList(),
          ),
        ],
        if (people.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildResultCategory(
            icon: Icons.people_outlined,
            color: AppColors.warning,
            title: 'People',
            items: people.asMap().entries.map((e) {
              final p = e.value as Map<String, dynamic>;
              return _ResultItem(
                key: 'person_${e.key}',
                title: p['name'] as String? ?? '',
                subtitle: p['context'] as String? ?? '',
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saveSelected,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Save Selected', style: AppTextStyles.button),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => setState(() {
              _extractedResults = null;
              _selectedItems = {};
            }),
            child: Text('Dismiss', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary)),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCategory({
    required IconData icon,
    required Color color,
    required String title,
    required List<_ResultItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Text(title, style: AppTextStyles.headlineSmall),
              ],
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          ...items.map((item) => CheckboxListTile(
                value: _selectedItems[item.key] ?? false,
                onChanged: (val) => setState(() => _selectedItems[item.key] = val ?? false),
                activeColor: AppColors.accent,
                checkColor: Colors.white,
                title: Text(item.title, style: AppTextStyles.bodyMedium),
                subtitle: item.subtitle.isNotEmpty
                    ? Text(item.subtitle, style: AppTextStyles.caption)
                    : null,
                controlAffinity: ListTileControlAffinity.trailing,
                dense: true,
              )),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_inboxHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(
              'Paste any conversation and ARIA will extract what matters',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'WhatsApp messages, emails, meeting notes — anything works.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent', style: AppTextStyles.headlineSmall),
        const SizedBox(height: 8),
        ...(_inboxHistory.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['text'] as String? ?? '',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if ((item['commitments_count'] as int? ?? 0) > 0)
                        _buildHistoryChip(
                          '${item['commitments_count']} commitment${(item['commitments_count'] as int) == 1 ? '' : 's'}',
                          AppColors.accent,
                        ),
                      if ((item['tasks_count'] as int? ?? 0) > 0) ...[
                        const SizedBox(width: 6),
                        _buildHistoryChip(
                          '${item['tasks_count']} task${(item['tasks_count'] as int) == 1 ? '' : 's'}',
                          AppColors.success,
                        ),
                      ],
                      if ((item['events_count'] as int? ?? 0) > 0) ...[
                        const SizedBox(width: 6),
                        _buildHistoryChip(
                          '${item['events_count']} event${(item['events_count'] as int) == 1 ? '' : 's'}',
                          AppColors.secondary,
                        ),
                      ],
                      const Spacer(),
                      if (item['timestamp'] != null)
                        Text(
                          _formatDate(item['timestamp'] as String),
                          style: AppTextStyles.caption,
                        ),
                    ],
                  ),
                ],
              ),
            ))),
      ],
    );
  }

  Widget _buildHistoryChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: color),
      ),
    );
  }

  String _formatDate(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }
}

class _ResultItem {
  final String key;
  final String title;
  final String subtitle;

  const _ResultItem({
    required this.key,
    required this.title,
    this.subtitle = '',
  });
}
