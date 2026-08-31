import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../core/theme/aria_color_scheme.dart';
import '../../../../shared/providers/theme_provider.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _selectedAssistantName = 'ARIA';
  final TextEditingController _customNameController = TextEditingController();
  bool _showCustomInput = false;

  final _calendarConnections = {
    'Google Calendar': false,
    'Apple Calendar': false,
    'Outlook Calendar': false,
  };

  final _commConnections = {
    'Email': false,
    'WhatsApp': false,
    'Slack': false,
    'SMS': false,
  };

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<String> _presetNames = ['ARIA', 'Nova', 'Atlas', 'Aura', 'Luna'];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _customNameController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    final assistantName =
        _showCustomInput && _customNameController.text.trim().isNotEmpty
            ? _customNameController.text.trim()
            : _selectedAssistantName;
    final notifier = ref.read(authProvider.notifier);
    notifier.updateAssistantName(assistantName);
    notifier.completeOnboarding();
    context.go('/home/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(),
                  _buildNamePage(),
                  _buildThemePage(),
                  _buildCalendarPage(),
                  _buildCommsPage(),
                  _buildPrivacyPage(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(6, (i) {
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 3,
              margin: EdgeInsets.only(right: i < 4 ? 6 : 0),
              decoration: BoxDecoration(
                color: i <= _currentPage ? AppColors.accent : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.accentGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.4),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 56,
            ),
          ),
          const SizedBox(height: 40),
          const Text('Meet Your New\nExecutive Assistant', style: AppTextStyles.displayMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            'ARIA remembers everything, detects your plans, and keeps your life organized — without ever acting without your approval.',
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          _buildFeatureRow(Icons.psychology_outlined, 'Second Brain Memory'),
          const SizedBox(height: 12),
          _buildFeatureRow(Icons.calendar_today_outlined, 'Smart Event Detection'),
          const SizedBox(height: 12),
          _buildFeatureRow(Icons.security_outlined, 'Your Data, Your Control'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Text(label, style: AppTextStyles.bodyMedium),
      ],
    );
  }

  Widget _buildNamePage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Name Your\nAssistant', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text(
            'Your assistant will always refer to itself by this name.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _presetNames.map((name) {
              final isSelected = !_showCustomInput && _selectedAssistantName == name;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedAssistantName = name;
                  _showCustomInput = false;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppColors.accentGradient : null,
                    color: isSelected ? null : AppColors.surface,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : AppColors.border,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 12)]
                        : null,
                  ),
                  child: Text(
                    name,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
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
              if (_showCustomInput) _customNameController.clear();
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
              controller: _customNameController,
              style: AppTextStyles.bodyLarge,
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
                  borderSide: BorderSide(color: AppColors.accent, width: 2),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              autofocus: true,
            ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _showCustomInput && _customNameController.text.isNotEmpty
                          ? _customNameController.text
                          : _selectedAssistantName,
                      style: AppTextStyles.headlineSmall,
                    ),
                    Text('Your AI Executive Assistant', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemePage() {
    final currentIndex = ref.watch(themeIndexProvider);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Choose Your\nColour Scheme', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text(
            'Pick a palette that feels like you. You can change this anytime in Settings.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 36),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
              ),
              itemCount: AriaColorScheme.presets.length,
              itemBuilder: (_, i) {
                final scheme = AriaColorScheme.presets[i];
                final isSelected = i == currentIndex;
                return GestureDetector(
                  onTap: () => ref.read(themeIndexProvider.notifier).setTheme(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? scheme.accent : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: scheme.accent.withOpacity(0.4), blurRadius: 16, spreadRadius: 2)]
                          : null,
                    ),
                    child: Stack(
                      children: [
                        // Mini preview gradient blob
                        Positioned(
                          top: -12,
                          right: -12,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: scheme.accentGradient,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(scheme.emoji, style: const TextStyle(fontSize: 22)),
                              const SizedBox(height: 4),
                              Text(
                                scheme.name,
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: scheme.accent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Connect\nYour Calendar', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text(
            'Let your assistant see your schedule and detect meetings automatically.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),
          ..._calendarConnections.entries.map((e) => _buildConnectionTile(
                e.key,
                _calendarIcon(e.key),
                _calendarConnections[e.key]!,
                (val) => setState(() => _calendarConnections[e.key] = val),
              )),
          const Spacer(),
          Text(
            'You can connect or disconnect calendars at any time in Settings.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCommsPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Connect\nCommunications', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text(
            'Your assistant will detect plans, commitments, and meetings from your messages.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),
          ..._commConnections.entries.map((e) => _buildConnectionTile(
                e.key,
                _commIcon(e.key),
                _commConnections[e.key]!,
                (val) => setState(() => _commConnections[e.key] = val),
              )),
          const Spacer(),
          Text(
            'Messages are analyzed locally. Your conversations are never stored on our servers.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPage() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          const Text('Your Privacy\nComes First', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text(
            'ARIA is built on a foundation of trust, transparency, and user control.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 40),
          _buildPrivacyItem(
            Icons.lock_outlined,
            'End-to-End Encrypted',
            'All your data is encrypted in transit and at rest.',
          ),
          _buildPrivacyItem(
            Icons.phone_android_outlined,
            'Local-First Processing',
            'Sensitive analysis happens on your device when possible.',
          ),
          _buildPrivacyItem(
            Icons.check_circle_outline,
            'Always Ask Before Acting',
            'ARIA suggests — you decide. Nothing happens without your approval.',
          ),
          _buildPrivacyItem(
            Icons.delete_outline,
            'Delete Anytime',
            'Export or delete all your data whenever you choose.',
          ),
          _buildPrivacyItem(
            Icons.visibility_outlined,
            'Full Transparency',
            'ARIA always explains why it\'s making a suggestion.',
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Ready to meet your new assistant?',
                    style: AppTextStyles.headlineSmall.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionTile(
      String name, IconData icon, bool connected, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connected ? AppColors.accent.withOpacity(0.5) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: connected ? AppColors.accent : AppColors.textSecondary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(name, style: AppTextStyles.bodyMedium),
          ),
          Switch(
            value: connected,
            onChanged: onChanged,
            activeColor: AppColors.accent,
            activeTrackColor: AppColors.accent.withOpacity(0.3),
            inactiveThumbColor: AppColors.textTertiary,
            inactiveTrackColor: AppColors.border,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Row(
        children: [
          if (_currentPage > 0)
            GestureDetector(
              onTap: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
              ),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: _nextPage,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _currentPage == 5 ? 'Get Started' : 'Continue',
                    style: AppTextStyles.button,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _calendarIcon(String name) {
    if (name.contains('Google')) return Icons.event_outlined;
    if (name.contains('Apple')) return Icons.apple;
    return Icons.calendar_month_outlined;
  }

  IconData _commIcon(String name) {
    switch (name) {
      case 'Email':
        return Icons.email_outlined;
      case 'WhatsApp':
        return Icons.chat_outlined;
      case 'Slack':
        return Icons.tag_outlined;
      case 'SMS':
        return Icons.sms_outlined;
      default:
        return Icons.message_outlined;
    }
  }
}
