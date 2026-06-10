import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/auth_failure.dart';
import '../../../core/localization/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_form_fields.dart';
import 'widgets/auth_colors.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/auth_timeline.dart';
import 'widgets/otp_input_field.dart';
import 'widgets/password_requirement_list.dart';
import 'widgets/password_strength_bar.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
    for (final c in [
      _emailController,
      _codeController,
      _passwordController,
      _confirmPasswordController,
    ]) {
      c.addListener(_updateSubmitState);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _emailController,
      _codeController,
      _passwordController,
      _confirmPasswordController,
    ]) {
      c.removeListener(_updateSubmitState);
      c.dispose();
    }
    super.dispose();
  }

  void _updateSubmitState() {
    final next =
        _emailController.text.trim().isNotEmpty &&
        _codeController.text.trim().length == 6 &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty;
    if (next != _canSubmit) {
      setState(() => _canSubmit = next);
    } else {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .confirmResetPassword(
            email: _emailController.text,
            confirmationCode: _codeController.text.trim(),
            newPassword: _passwordController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.text('resetPasswordSuccess'))),
        );
        context.go('/login');
      }
    } on AuthFailure catch (f) {
      _showError(f.message);
    } catch (_) {
      _showError(l10n.unknownError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthScaffold(
      leading: Align(
        alignment: Alignment.centerLeft,
        child: IconButton.filledTonal(
          tooltip: l10n.back,
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ──────────────────────────────────────────
            const AuthHeader(
              compact: true,
              title: 'Tạo mật khẩu\nmới',
              subtitle:
                  'Nhập mã OTP từ email và đặt mật khẩu mới cho tài khoản.',
              icon: Icons.lock_reset_outlined,
            ),
            const SizedBox(height: 24),

            // ── Timeline — step 3 active ─────────────────────────
            const AuthTimeline(
              activeIndex: 2,
              steps: [
                AuthTimelineStep(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email',
                ),
                AuthTimelineStep(icon: Icons.pin_outlined, label: 'OTP'),
                AuthTimelineStep(
                  icon: Icons.lock_reset_outlined,
                  label: 'Mật khẩu mới',
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Form card ─────────────────────────────────────────
            AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Email — show or input
                  if (widget.email == null || widget.email!.trim().isEmpty) ...[
                    AuthTextField(
                      controller: _emailController,
                      label: l10n.email,
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => emailValidator(
                        v,
                        requiredMessage: l10n.emailRequired,
                        invalidMessage: l10n.text('invalidEmail'),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ] else ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AuthColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AuthColors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.mail_outline_rounded,
                              size: 15,
                              color: AuthColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _emailController.text,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AuthColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // OTP code
                  Text(
                    'Mã xác nhận OTP',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AuthColors.textSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OtpInputField(
                    controller: _codeController,
                    onChanged: (_) => _updateSubmitState(),
                  ),
                  const SizedBox(height: 20),

                  // New password
                  AuthTextField(
                    controller: _passwordController,
                    label: l10n.newPassword,
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    validator: (v) => cognitoPasswordValidator(
                      v,
                      requiredMessage: l10n.passwordRequired,
                      weakPasswordMessage: l10n.weakPassword,
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
                  const SizedBox(height: 12),
                  PasswordStrengthBar(password: _passwordController.text),
                  const SizedBox(height: 12),
                  PasswordRequirementList(password: _passwordController.text),
                  const SizedBox(height: 14),

                  // Confirm password
                  AuthTextField(
                    controller: _confirmPasswordController,
                    label: l10n.confirmNewPassword,
                    icon: Icons.lock_reset_outlined,
                    obscureText: _obscureConfirmPassword,
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return l10n.passwordMismatch;
                      }
                      return requiredTextValidator(
                        v,
                        message: l10n.passwordRequired,
                      );
                    },
                    suffix: IconButton(
                      tooltip: _obscureConfirmPassword
                          ? l10n.text('showPassword')
                          : l10n.text('hidePassword'),
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  AuthPrimaryButton(
                    label: 'Đổi mật khẩu',
                    icon: Icons.password_outlined,
                    isLoading: _isSubmitting,
                    onPressed: _canSubmit ? _submit : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
