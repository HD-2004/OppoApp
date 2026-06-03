import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/auth_failure.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/domain/app_role.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import 'auth_form_fields.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  static const _brandTeal = Color(0xFF08798A);
  static const _deepText = Color(0xFF061B2B);
  static const _mutedText = Color(0xFF40525A);
  static const _warmBackground = Color(0xFFF8FAFF);

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final l10n = AppLocalizations.of(context);

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            RegisterRequest(
              fullName: _fullNameController.text,
              email: _emailController.text,
              password: _passwordController.text,
              role: AppRole.candidate,
            ),
          );
    } on AuthFailure catch (failure) {
      _showError(failure.message);
    } catch (error) {
      _showError(l10n.unknownError);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _warmBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.appName,
                    style: textTheme.headlineMedium?.copyWith(
                      color: _brandTeal,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tạo hồ sơ ứng viên để bắt đầu tìm ca làm F&B phù hợp.',
                    style: textTheme.bodyLarge?.copyWith(
                      color: _mutedText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 42),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _brandTeal.withValues(alpha: 0.12),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.signUp,
                              style: textTheme.headlineSmall?.copyWith(
                                color: _deepText,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Chỉ dành cho người dùng/ứng viên. Bạn có thể cập nhật hồ sơ sau khi đăng ký.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: _mutedText,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _fullNameController,
                              style: authInputTextStyle,
                              textInputAction: TextInputAction.next,
                              decoration: authInputDecoration(
                                label: l10n.fullName,
                                icon: Icons.badge_outlined,
                              ),
                              validator: (value) => requiredTextValidator(
                                value,
                                message: l10n.text('requiredField'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _emailController,
                              style: authInputTextStyle,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: authInputDecoration(
                                label: l10n.email,
                                icon: Icons.mail_outline_rounded,
                              ),
                              validator: (value) => requiredTextValidator(
                                value,
                                message: l10n.emailRequired,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordController,
                              style: authInputTextStyle,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              decoration:
                                  authInputDecoration(
                                    label: l10n.password,
                                    icon: Icons.lock_outline_rounded,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      tooltip: _obscurePassword
                                          ? l10n.text('showPassword')
                                          : l10n.text('hidePassword'),
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                              validator: (value) => cognitoPasswordValidator(
                                value,
                                requiredMessage: l10n.passwordRequired,
                                weakPasswordMessage: l10n.weakPassword,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _confirmPasswordController,
                              style: authInputTextStyle,
                              obscureText: _obscureConfirmPassword,
                              decoration:
                                  authInputDecoration(
                                    label: l10n.confirmPassword,
                                    icon: Icons.lock_reset_outlined,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      tooltip: _obscureConfirmPassword
                                          ? l10n.text('showPassword')
                                          : l10n.text('hidePassword'),
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      ),
                                    ),
                                  ),
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return l10n.passwordMismatch;
                                }
                                return requiredTextValidator(
                                  value,
                                  message: l10n.passwordRequired,
                                );
                              },
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              height: 56,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _brandTeal,
                                  foregroundColor: Colors.white,
                                  textStyle: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: _isSubmitting ? null : _submit,
                                icon: _isSubmitting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.person_add_alt_1),
                                label: Text(l10n.signUp),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text(
                      'Bạn đã có tài khoản? Đăng nhập',
                      style: TextStyle(
                        color: _brandTeal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
