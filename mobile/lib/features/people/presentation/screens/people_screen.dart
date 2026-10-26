import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/models/person_context.dart';
import '../../../../shared/providers/people_provider.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _avatarColor(String relationship) {
    switch (relationship) {
      case 'colleague':
        return AppColors.accent;
      case 'friend':
        return const Color(0xFF66BB6A);
      case 'family':
        return const Color(0xFFFF7043);
      case 'client':
        return const Color(0xFFFFCA28);
      case 'vendor':
        return const Color(0xFFAB47BC);
      default:
        return AppColors.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = ref.watch(peopleProvider);
    final filtered = _searchQuery.isEmpty
        ? people
        : people.where((p) {
            final q = _searchQuery.toLowerCase();
            return p.name.toLowerCase().contains(q) ||
                p.relationship.toLowerCase().contains(q) ||
                p.notes.toLowerCase().contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('People', style: AppTextStyles.headlineLarge),
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_outlined, color: AppColors.accent),
            onPressed: () => _showAddEditSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildPersonCard(context, filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        style: AppTextStyles.bodyMedium,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search people...',
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.accent, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPersonCard(BuildContext context, PersonContext person) {
    final now = DateTime.now();
    final isFollowUpOverdue =
        person.followUpDate != null && person.followUpDate!.isBefore(now);
    final isFollowUpSoon = person.followUpDate != null &&
        !isFollowUpOverdue &&
        person.followUpDate!.difference(now).inDays <= 7;

    final initials = person.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return GestureDetector(
      onTap: () => _showDetailSheet(context, person),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _avatarColor(person.relationship).withOpacity(0.2),
              child: Text(
                initials,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: _avatarColor(person.relationship),
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(person.name, style: AppTextStyles.headlineSmall),
                      ),
                      _buildRelationshipBadge(person.relationship),
                    ],
                  ),
                  if (person.notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      person.notes,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (person.lastContact != null)
                        Text(
                          'Last contact: ${_formatRelativeDate(person.lastContact!)}',
                          style: AppTextStyles.caption,
                        ),
                      const Spacer(),
                      if (isFollowUpOverdue)
                        _buildChip('Follow up overdue', AppColors.error),
                      if (isFollowUpSoon)
                        _buildChip('Follow up soon', AppColors.warning),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipBadge(String relationship) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _avatarColor(relationship).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        relationship,
        style: AppTextStyles.caption.copyWith(color: _avatarColor(relationship)),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(color: color),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, color: AppColors.textTertiary, size: 56),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No people yet' : 'No results for "$_searchQuery"',
            style: AppTextStyles.headlineSmall.copyWith(color: AppColors.textTertiary),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Add people ARIA should know about',
              style: AppTextStyles.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  void _showDetailSheet(BuildContext context, PersonContext person) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: _PersonDetailContent(
            person: person,
            avatarColor: _avatarColor(person.relationship),
            onEdit: () {
              Navigator.pop(context);
              _showAddEditSheet(context, person: person);
            },
            onDelete: () {
              ref.read(peopleProvider.notifier).deletePerson(person.id);
              Navigator.pop(context);
            },
          ),
        ),
      ),
    );
  }

  void _showAddEditSheet(BuildContext context, {PersonContext? person}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _PersonFormSheet(
          existing: person,
          onSave: (updated) {
            if (person == null) {
              ref.read(peopleProvider.notifier).addPerson(updated);
            } else {
              ref.read(peopleProvider.notifier).updatePerson(updated);
            }
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).round()}w ago';
    return '${(diff.inDays / 30).round()}mo ago';
  }
}

// ─── Detail sheet ────────────────────────────────────────────────────────────

class _PersonDetailContent extends StatelessWidget {
  final PersonContext person;
  final Color avatarColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PersonDetailContent({
    required this.person,
    required this.avatarColor,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final initials = person.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: avatarColor.withOpacity(0.2),
              child: Text(
                initials,
                style: AppTextStyles.displaySmall.copyWith(color: avatarColor),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name, style: AppTextStyles.headlineLarge),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: avatarColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      person.relationship,
                      style: AppTextStyles.labelMedium.copyWith(color: avatarColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (person.email != null || person.phone != null) ...[
          _detailRow(Icons.email_outlined, person.email ?? '—'),
          const SizedBox(height: 8),
          _detailRow(Icons.phone_outlined, person.phone ?? '—'),
          const SizedBox(height: 16),
        ],
        if (person.notes.isNotEmpty) ...[
          Text('Notes', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(person.notes, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
        ],
        if (person.preferences.isNotEmpty) ...[
          Text('Preferences', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(person.preferences, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 16),
        ],
        if (person.followUpDate != null) ...[
          Text('Follow-up', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.alarm_outlined,
                size: 16,
                color: person.followUpDate!.isBefore(DateTime.now())
                    ? AppColors.error
                    : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                '${_formatDate(person.followUpDate!)}${person.followUpNote != null ? ' — ${person.followUpNote}' : ''}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: person.followUpDate!.isBefore(DateTime.now())
                      ? AppColors.error
                      : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (person.lastContact != null) ...[
          Text('Last contact', style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(_formatDate(person.lastContact!), style: AppTextStyles.bodySmall),
          const SizedBox(height: 20),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outlined, size: 18),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 8),
        Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day} ${_monthName(date.month)} ${date.year}';
  }

  String _monthName(int m) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[m];
  }
}

// ─── Form sheet ──────────────────────────────────────────────────────────────

class _PersonFormSheet extends StatefulWidget {
  final PersonContext? existing;
  final void Function(PersonContext) onSave;

  const _PersonFormSheet({this.existing, required this.onSave});

  @override
  State<_PersonFormSheet> createState() => _PersonFormSheetState();
}

class _PersonFormSheetState extends State<_PersonFormSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _notesController = TextEditingController();
  final _prefsController = TextEditingController();
  final _followUpNoteController = TextEditingController();
  String _relationship = 'colleague';
  DateTime? _followUpDate;

  static const _relationships = [
    'colleague', 'friend', 'family', 'client', 'vendor', 'other'
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    if (p != null) {
      _nameController.text = p.name;
      _phoneController.text = p.phone ?? '';
      _emailController.text = p.email ?? '';
      _notesController.text = p.notes;
      _prefsController.text = p.preferences;
      _followUpNoteController.text = p.followUpNote ?? '';
      _relationship = p.relationship;
      _followUpDate = p.followUpDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    _prefsController.dispose();
    _followUpNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(isEditing ? 'Edit Person' : 'Add Person', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 20),
          _field('Name *', _nameController, 'e.g. Raj Sharma'),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _relationship,
            dropdownColor: AppColors.surface,
            style: AppTextStyles.bodyMedium,
            decoration: _inputDecoration('Relationship'),
            items: _relationships
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (v) => setState(() => _relationship = v ?? 'colleague'),
          ),
          const SizedBox(height: 12),
          _field('Phone', _phoneController, 'optional'),
          const SizedBox(height: 12),
          _field('Email', _emailController, 'optional'),
          const SizedBox(height: 12),
          _field('Notes', _notesController, 'What should ARIA know about this person?', maxLines: 3),
          const SizedBox(height: 12),
          _field('Preferences', _prefsController, 'e.g. prefers email, no calls before 10am', maxLines: 2),
          const SizedBox(height: 12),
          _buildDatePicker(),
          const SizedBox(height: 12),
          _field('Follow-up note', _followUpNoteController, 'What to follow up about?'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(isEditing ? 'Save Changes' : 'Add Person', style: AppTextStyles.button),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: AppTextStyles.bodyMedium,
      decoration: _inputDecoration(label).copyWith(hintText: hint),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.accent, width: 2),
      ),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: AppColors.textTertiary),
            const SizedBox(width: 12),
            Text(
              _followUpDate == null
                  ? 'Follow-up date (optional)'
                  : 'Follow up: ${_followUpDate!.day}/${_followUpDate!.month}/${_followUpDate!.year}',
              style: AppTextStyles.bodyMedium.copyWith(
                color: _followUpDate == null ? AppColors.textTertiary : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (_followUpDate != null)
              GestureDetector(
                onTap: () => setState(() => _followUpDate = null),
                child: Icon(Icons.close, size: 16, color: AppColors.textTertiary),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.accent),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _followUpDate = picked);
  }

  void _onSave() {
    if (_nameController.text.trim().isEmpty) return;
    final p = widget.existing;
    final updated = PersonContext(
      id: p?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      relationship: _relationship,
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      notes: _notesController.text.trim(),
      preferences: _prefsController.text.trim(),
      lastContact: p?.lastContact,
      followUpDate: _followUpDate,
      followUpNote: _followUpNoteController.text.trim().isEmpty ? null : _followUpNoteController.text.trim(),
      createdAt: p?.createdAt ?? DateTime.now(),
    );
    widget.onSave(updated);
  }
}
