import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/auth_failure.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../main.dart' show amplifyConfigError, amplifyConfigDebugInfo;
import '../../candidate/presentation/policy_terms_screen.dart';
import '../application/auth_controller.dart';
import '../data/check_email_service.dart';
import 'auth_form_fields.dart';
import 'widgets/auth_colors.dart';
import 'widgets/auth_footer_link.dart';
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
  // Lỗi inline hiển thị ngay dưới ô Email (từ check-email API).
  String? _emailError;

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
    // Xóa lỗi inline khi user thay đổi email
    if (_emailError != null) setState(() => _emailError = null);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _emailError = null;
    });
    try {
      // ── Bước 1: kiểm tra email trước khi đăng nhập bằng password ──────────
      final checker = const CheckEmailService();
      final result = await checker.check(_emailController.text.trim());

      if (result.isGoogle) {
        // Email đã đăng ký qua Google — dừng lại, hiện lỗi inline
        setState(() {
          _emailError =
              "Tài khoản này đăng ký qua Google. Vui lòng dùng nút 'Đăng nhập với Google' bên dưới.";
        });
        return;
      }

      // Nếu native hoặc không tồn tại → tiếp tục, để backend tự báo lỗi
      // ── Bước 2: đăng nhập thông thường ────────────────────────────────────
      await ref
          .read(authControllerProvider.notifier)
          .signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on CheckEmailException catch (e) {
      // Lỗi gọi check-email API — hiện snackbar và vẫn cho phép thử đăng nhập
      _showError('CheckEmail: ${e.message}');
      // Fallthrough: không block luồng đăng nhập khi API check lỗi
      try {
        await ref
            .read(authControllerProvider.notifier)
            .signIn(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
      } on AuthFailure catch (failure) {
        _showError('${failure.message} [code=${failure.code}]');
        if (failure.code == 'user_unconfirmed' && mounted) {
          context.go(
            '/confirm-signup?email=${Uri.encodeComponent(_emailController.text)}',
          );
        }
      } catch (e2) {
        _showError('RAW inner: $e2');
      }
    } on AuthFailure catch (failure) {
      _showError('${failure.message} [code=${failure.code}]');
      if (failure.code == 'user_unconfirmed' && mounted) {
        context.go(
          '/confirm-signup?email=${Uri.encodeComponent(_emailController.text)}',
        );
      }
    } catch (e) {
      _showError('RAW: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitSocial(AuthProvider provider) async {
    if (_isSubmitting || _socialProviderSubmitting != null) return;
    setState(() => _socialProviderSubmitting = provider);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signInWithSocialProvider(provider);
    } on AuthFailure catch (f) {
      _showError('${f.message} [code=${f.code}]');
    } catch (e) {
      _showError('RAW social: $e');
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
                  // Lỗi inline từ check-email API (email đã đăng ký qua Google)
                  if (_emailError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 14),
                      child: Text(
                        _emailError!,
                        style: const TextStyle(
                          color: AuthColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
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
                  AuthSocialButton(
                    label: 'Google',
                    iconText: 'G',
                    accentColor: const Color(0xFFE04F3D),
                    isLoading: _socialProviderSubmitting == AuthProvider.google,
                    onPressed:
                        _socialProviderSubmitting == null && !_isSubmitting
                        ? () => _submitSocial(AuthProvider.google)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AuthFooterLink(
              text: 'Chưa có tài khoản?',
              actionText: 'Đăng ký ngay',
              onPressed: () => context.go('/register'),
            ),
            const SizedBox(height: 4),
            const PolicyInlineLinks(),
            const SizedBox(height: 8),
            // ── Debug: show Amplify config error details ──────────────
            if (amplifyConfigError != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade900.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  amplifyConfigError!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            // ── Debug: always show config values ──────────────────────
            if (amplifyConfigDebugInfo != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  amplifyConfigDebugInfo!,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
