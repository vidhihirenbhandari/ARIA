import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _showEmailForm = false;
  bool _isCreatingAccount = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Please fill in all fields'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (_isCreatingAccount) {
      final name = _nameController.text.trim();
      final confirm = _confirmPasswordController.text;
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Please enter your name'), backgroundColor: AppColors.error),
        );
        return;
      }
      if (password != confirm) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Passwords do not match'), backgroundColor: AppColors.error),
        );
        return;
      }
      ref.read(authProvider.notifier).createAccount(email, password, name);
    } else {
      ref.read(authProvider.notifier).signInWithEmail(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (_, next) {
      if (next.status == AuthStatus.authenticated) {
        if (next.user?.onboardingComplete == true) {
          context.go('/home');
        } else {
          context.go('/onboarding');
        }
      } else if (next.status == AuthStatus.error && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60),
                // Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.accentGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 32),
                Text('Welcome to ARIA', style: AppTextStyles.displaySmall, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  'Your intelligent personal assistant',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Google Sign-In
                _SocialSignInButton(
                  onTap: authState.isLoading
                      ? null
                      : () => ref.read(authProvider.notifier).signInWithGoogle(),
                  icon: 'G',
                  label: 'Continue with Google',
                  backgroundColor: Colors.white,
                  textColor: const Color(0xFF1F1F1F),
                  iconColor: const Color(0xFF4285F4),
                ),
                const SizedBox(height: 24),

                _divider(),
                const SizedBox(height: 24),

                // Email form toggle
                AnimatedCrossFade(
                  firstChild: OutlinedButton(
                    onPressed: () => setState(() => _showEmailForm = true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Continue with Email',
                      style: AppTextStyles.button.copyWith(color: AppColors.textSecondary),
                    ),
                  ),
                  secondChild: _EmailForm(
                    nameController: _nameController,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    confirmPasswordController: _confirmPasswordController,
                    obscurePassword: _obscurePassword,
                    obscureConfirm: _obscureConfirm,
                    isCreatingAccount: _isCreatingAccount,
                    isLoading: authState.isLoading,
                    onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
                    onToggleConfirm: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    onSubmit: _submit,
                    onToggleMode: () => setState(() {
                      _isCreatingAccount = !_isCreatingAccount;
                      _nameController.clear();
                      _emailController.clear();
                      _passwordController.clear();
                      _confirmPasswordController.clear();
                    }),
                  ),
                  crossFadeState: _showEmailForm ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),

                const SizedBox(height: 24),

                // Demo mode
                GestureDetector(
                  onTap: authState.isLoading
                      ? null
                      : () => ref.read(authProvider.notifier).signInAsDemo(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent.withOpacity(0.08),
                          AppColors.secondary.withOpacity(0.08),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.rocket_launch_rounded, color: AppColors.accent, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          'Try Demo — No sign-up needed',
                          style: AppTextStyles.button.copyWith(color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),
                Text(
                  'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                if (authState.isLoading)
                  Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

class _SocialSignInButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? iconColor;

  const _SocialSignInButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: iconColor ?? textColor),
            ),
            const SizedBox(width: 12),
            Text(label, style: AppTextStyles.button.copyWith(color: textColor)),
          ],
        ),
      ),
    );
  }
}

class _EmailForm extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirm;
  final bool isCreatingAccount;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;

  const _EmailForm({
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirm,
    required this.isCreatingAccount,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
    required this.onToggleMode,
  });

  InputDecoration _inputDecoration(String hint, IconData prefixIcon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: AppColors.textTertiary),
      suffixIcon: suffix,
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
        borderSide: BorderSide(color: AppColors.accent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sign In / Create Account toggle header
        Row(
          children: [
            _ModeTab(label: 'Sign In', selected: !isCreatingAccount, onTap: isCreatingAccount ? onToggleMode : null),
            const SizedBox(width: 8),
            _ModeTab(label: 'Create Account', selected: isCreatingAccount, onTap: !isCreatingAccount ? onToggleMode : null),
          ],
        ),
        const SizedBox(height: 16),

        if (isCreatingAccount) ...[
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            style: AppTextStyles.bodyMedium,
            decoration: _inputDecoration('Your name', Icons.person_outline_rounded),
          ),
          const SizedBox(height: 12),
        ],

        TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          style: AppTextStyles.bodyMedium,
          decoration: _inputDecoration('Email address', Icons.email_outlined),
        ),
        const SizedBox(height: 12),

        TextField(
          controller: passwordController,
          obscureText: obscurePassword,
          style: AppTextStyles.bodyMedium,
          decoration: _inputDecoration(
            'Password',
            Icons.lock_outline_rounded,
            suffix: IconButton(
              onPressed: onTogglePassword,
              icon: Icon(
                obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ),

        if (isCreatingAccount) ...[
          const SizedBox(height: 12),
          TextField(
            controller: confirmPasswordController,
            obscureText: obscureConfirm,
            style: AppTextStyles.bodyMedium,
            decoration: _inputDecoration(
              'Confirm password',
              Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: onToggleConfirm,
                icon: Icon(
                  obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isCreatingAccount ? 'Create Account' : 'Sign In',
              style: AppTextStyles.button,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeTab({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: selected ? AppColors.accent : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
