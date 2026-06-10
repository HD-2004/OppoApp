import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/auth_failure.dart';
import '../../../core/localization/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_form_fields.dart';
import 'widgets/auth_colors.dart';
import 'widgets/auth_footer_link.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;
  AuthProvider? _socialProviderSubmitting;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_updateSubmitState);
    _passwordController.addListener(_updateSubmitState);
  }

  @override
  void dispose() {
    _emailController.removeListener(_updateSubmitState);
    _passwordController.removeListener(_updateSubmitState);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateSubmitState() {
    final next =
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty;
    if (next != _canSubmit) setState(() => _canSubmit = next);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on AuthFailure catch (failure) {
      _showError(failure.message);
      if (failure.code == 'user_unconfirmed' && mounted) {
        context.go(
          '/confirm-signup?email=${Uri.encodeComponent(_emailController.text)}',
        );
      }
    } catch (_) {
      _showError(l10n.unknownError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitSocial(AuthProvider provider) async {
    if (_isSubmitting || _socialProviderSubmitting != null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _socialProviderSubmitting = provider);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signInWithSocialProvider(provider);
    } on AuthFailure catch (f) {
      _showError(f.message);
    } catch (_) {
      _showError(l10n.unknownError);
    } finally {
      if (mounted) setState(() => _socialProviderSubmitting = null);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AuthScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Logo + Hero ──────────────────────────────────────
            const AuthHeader(),
            const SizedBox(height: 20),

            // ── Feature highlights ────────────────────────────────
            _FeatureHighlights(),
            const SizedBox(height: 28),

            // ── Form card ─────────────────────────────────────────
            AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthCardTitle(
                    title: 'Đăng nhập',
                    subtitle: 'Tiếp tục tìm ca phù hợp và quản lý thu nhập.',
                  ),
                  const SizedBox(height: 22),
                  AuthTextField(
                    controller: _emailController,
                    label: l10n.email,
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) => emailValidator(
                      v,
                      requiredMessage: l10n.emailRequired,
                      invalidMessage: l10n.text('invalidEmail'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _passwordController,
                    label: l10n.password,
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    validator: (v) => requiredTextValidator(
                      v,
                      message: l10n.passwordRequired,
                    ),
                    suffix: IconButton(
                      tooltip: _obscurePassword
                          ? l10n.text('showPassword')
                          : l10n.text('hidePassword'),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go(
                        '/forgot-password?email=${Uri.encodeComponent(_emailController.text.trim())}',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AuthColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                      ),
                      child: Text(
                        l10n.forgotPassword,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AuthPrimaryButton(
                    label: l10n.signIn,
                    icon: Icons.login_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _canSubmit ? _submit : null,
                  ),
                  const SizedBox(height: 18),
                  const AuthSectionDivider(label: 'Hoặc đăng nhập với'),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AuthSocialButton(
                          label: 'Google',
                          iconText: 'G',
                          accentColor: const Color(0xFFE04F3D),
                          isLoading:
                              _socialProviderSubmitting == AuthProvider.google,
                          onPressed:
                              _socialProviderSubmitting == null &&
                                  !_isSubmitting
                              ? () => _submitSocial(AuthProvider.google)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AuthSocialButton(
                          label: 'Facebook',
                          iconText: 'f',
                          accentColor: const Color(0xFF3167B7),
                          isLoading:
                              _socialProviderSubmitting ==
                              AuthProvider.facebook,
                          onPressed:
                              _socialProviderSubmitting == null &&
                                  !_isSubmitting
                              ? () => _submitSocial(AuthProvider.facebook)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AuthFooterLink(
              text: 'Chưa có tài khoản?',
              actionText: 'Đăng ký ngay',
              onPressed: () => context.go('/register'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Feature highlights ────────────────────────────────────────────────────────

class _FeatureHighlights extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = AuthColors.isDark(context);
    final items = const [
      (Icons.work_outline_rounded, 'Tìm việc nhanh'),
      (Icons.schedule_outlined, 'Chủ động ca làm'),
      (Icons.payments_outlined, 'Nhận lương liền'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: isDark
            ? AuthColors.primary.withValues(alpha: 0.08)
            : AuthColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AuthColors.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          return Expanded(
            child: _FeatureItem(icon: item.$1, label: item.$2),
          );
        }).toList(),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AuthColors.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AuthColors.primary, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AuthColors.textPrimary(context),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
