import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../widgets/common/fs7_logo.dart';
import '../../../widgets/common/app_button.dart';
import '../../../widgets/common/app_text_field.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  final _localAuth = LocalAuthentication();
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final available = await _localAuth.canCheckBiometrics;
      final supported = await _localAuth.isDeviceSupported();
      if (mounted) setState(() => _biometricAvailable = available && supported);
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    _userIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final user = await ref.read(authNotifierProvider.notifier).login(
        _userIdController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (user == null) {
        setState(() { _errorMessage = 'Invalid credentials'; _isLoading = false; });
        return;
      }
      if (user.mustChangePassword) {
        context.go('/change-password');
        return;
      }
      _navigateByRole(user.role);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _biometricLogin() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access FS-7',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (authenticated && mounted) {
        // Biometric unlocks the stored session — Supabase handles this
        final user = ref.read(currentUserProvider);
        if (user != null) _navigateByRole(user.role);
      }
    } catch (_) {}
  }

  void _navigateByRole(String role) {
    switch (role) {
      case 'admin': context.go('/admin'); break;
      case 'trainer': context.go('/trainer'); break;
      case 'nutritionist': context.go('/nutritionist'); break;
      default: context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    // Logo
                    const FS7Logo(size: 120),
                    const SizedBox(height: 16),
                    Text(
                      'Staff Login',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // User ID
                    AppTextField(
                      controller: _userIdController,
                      label: 'User ID',
                      hint: 'Enter your user ID',
                      prefixIcon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Password
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password',
                      hint: 'Enter your password',
                      prefixIcon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),

                    // Error
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error, fontSize: 13),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),

                    // Login button
                    AppButton(
                      label: 'Login',
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _login,
                    ),

                    if (_biometricAvailable) ...[
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: _biometricLogin,
                        icon: const Icon(Icons.fingerprint, color: AppColors.brandOrange),
                        label: const Text(
                          'Use Biometric',
                          style: TextStyle(color: AppColors.brandOrange),
                        ),
                      ),
                    ],

                    const SizedBox(height: 48),
                    Text(
                      'FS-7 Fitness — Staff App',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

