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

enum _ResetPasswordStep { otp, password }

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
  _ResetPasswordStep _step = _ResetPasswordStep.otp;
  String? _resetToken;
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
    final hasEmail = _emailController.text.trim().isNotEmpty;
    final next = switch (_step) {
      _ResetPasswordStep.otp =>
        hasEmail && _codeController.text.trim().length == 6,
      _ResetPasswordStep.password =>
        hasEmail &&
            _resetToken != null &&
            _passwordController.text.isNotEmpty &&
            _confirmPasswordController.text.isNotEmpty,
    };
    if (next != _canSubmit) {
      setState(() => _canSubmit = next);
    } else {
      setState(() {});
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isSubmitting = true);
    try {
      final token = await ref
          .read(authControllerProvider.notifier)
          .verifyResetPasswordOtp(
            email: _emailController.text,
            otp: _codeController.text.trim(),
          );
      if (mounted) {
        setState(() {
          _resetToken = token;
          _step = _ResetPasswordStep.password;
          _canSubmit = false;
        });
      }
    } on AuthFailure catch (f) {
      _showError(f.message);
    } catch (_) {
      _showError(l10n.unknownError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final resetToken = _resetToken;
    if (resetToken == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .confirmResetPasswordWithToken(
            email: _emailController.text,
            resetToken: resetToken,
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
    final isOtpStep = _step == _ResetPasswordStep.otp;

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
            AuthHeader(
              compact: true,
              title: isOtpStep ? 'Xác thực\nOTP' : 'Tạo mật khẩu\nmới',
              subtitle: isOtpStep
                  ? 'Nhập mã OTP từ email để xác nhận trước khi đổi mật khẩu.'
                  : 'Thiết lập mật khẩu mới cho tài khoản của bạn.',
              icon: isOtpStep
                  ? Icons.mark_email_read_outlined
                  : Icons.lock_reset_outlined,
            ),
            const SizedBox(height: 24),

            // ── Timeline — step 3 active ─────────────────────────
            AuthTimeline(
              activeIndex: isOtpStep ? 1 : 2,
              steps: const [
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

                  if (isOtpStep)
                    ..._buildOtpStep(context)
                  else ...[
                    ..._buildPasswordStep(context, l10n),
                  ],
                  const SizedBox(height: 22),
                  AuthPrimaryButton(
                    label: isOtpStep ? l10n.text('verifyOtp') : 'Đổi mật khẩu',
                    icon: isOtpStep
                        ? Icons.verified_user_outlined
                        : Icons.password_outlined,
                    isLoading: _isSubmitting,
                    onPressed: _canSubmit
                        ? (isOtpStep ? _verifyOtp : _submit)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOtpStep(BuildContext context) {
    return [
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
    ];
  }

  List<Widget> _buildPasswordStep(BuildContext context, AppLocalizations l10n) {
    return [
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
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      const SizedBox(height: 12),
      PasswordStrengthBar(password: _passwordController.text),
      const SizedBox(height: 12),
      PasswordRequirementList(password: _passwordController.text),
      const SizedBox(height: 14),
      AuthTextField(
        controller: _confirmPasswordController,
        label: l10n.confirmNewPassword,
        icon: Icons.lock_reset_outlined,
        obscureText: _obscureConfirmPassword,
        validator: (v) {
          if (v != _passwordController.text) {
            return l10n.passwordMismatch;
          }
          return requiredTextValidator(v, message: l10n.passwordRequired);
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
            () => _obscureConfirmPassword = !_obscureConfirmPassword,
          ),
        ),
      ),
    ];
  }
}
