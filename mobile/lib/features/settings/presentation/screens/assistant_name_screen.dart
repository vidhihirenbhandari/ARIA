import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/settings_provider.dart';

class AssistantNameScreen extends ConsumerStatefulWidget {
  const AssistantNameScreen({super.key});

  @override
  ConsumerState<AssistantNameScreen> createState() => _AssistantNameScreenState();
}

class _AssistantNameScreenState extends ConsumerState<AssistantNameScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _showCustomInput = false;
  String _previewName = '';

  final List<String> _presetNames = ['ARIA', 'Nova', 'Atlas', 'Aura', 'Luna', 'Ivy'];

  @override
  void initState() {
    super.initState();
    _previewName = ref.read(settingsProvider).assistantName;
    if (!_presetNames.contains(_previewName)) {
      _showCustomInput = true;
      _controller.text = _previewName;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Assistant Name', style: AppTextStyles.headlineLarge),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildPreviewCard(settings.assistantName),
          const SizedBox(height: 32),
          const Text('Choose a Name', style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presetNames.map((name) {
              final isSelected = !_showCustomInput && _previewName == name;
              return GestureDetector(
                onTap: () => setState(() {
                  _previewName = name;
                  _showCustomInput = false;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.accentGradient : null,
                    color: isSelected ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : AppColors.border,
                    ),
                  ),
                  child: Text(
                    name,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => setState(() {
              _showCustomInput = !_showCustomInput;
              if (_showCustomInput) _controller.clear();
            }),
            child: Row(
              children: [
                Icon(
                  _showCustomInput ? Icons.keyboard_arrow_up : Icons.add,
                  color: AppColors.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Use a custom name',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.accent),
                ),
              ],
            ),
          ),
          if (_showCustomInput) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              style: AppTextStyles.bodyLarge,
              onChanged: (v) => setState(() => _previewName = v),
              decoration: InputDecoration(
                hintText: 'Enter a name...',
                hintStyle: AppTextStyles.bodyLarge.copyWith(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.accent, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              autofocus: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewCard(String currentName) {
    final displayName = _showCustomInput && _controller.text.isNotEmpty
        ? _controller.text
        : _previewName;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A3E), Color(0xFF0F1728)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 16),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName.isEmpty ? 'ARIA' : displayName,
                style: AppTextStyles.headlineLarge,
              ),
              Text(
                'Your AI Executive Assistant',
                style: AppTextStyles.caption.copyWith(color: AppColors.accent),
              ),
              const SizedBox(height: 8),
              Text(
                '"Good morning! Here\'s your day..."',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _save() {
    final name = _showCustomInput && _controller.text.trim().isNotEmpty
        ? _controller.text.trim()
        : _previewName;
    ref.read(settingsProvider.notifier).setAssistantName(name);
    Navigator.pop(context);
  }
}
