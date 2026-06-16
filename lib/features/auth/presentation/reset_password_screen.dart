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

class ResetPasswordSession {
  const ResetPasswordSession({
    required this.email,
    required this.confirmationCode,
  });

  final String email;
  final String confirmationCode;
}

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
  bool _canContinue = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
    _emailController.addListener(_updateContinueState);
    _codeController.addListener(_updateContinueState);
    _updateContinueState();
  }

  @override
  void dispose() {
    _emailController.removeListener(_updateContinueState);
    _codeController.removeListener(_updateContinueState);
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _updateContinueState() {
    final next =
        _emailController.text.trim().isNotEmpty &&
        _codeController.text.trim().length == 6;
    if (next != _canContinue) {
      setState(() => _canContinue = next);
    } else if (mounted) {
      setState(() {});
    }
  }

  void _continueToPassword() {
    if (!_formKey.currentState!.validate()) return;
    context.push(
      '/reset-password/new-password',
      extra: ResetPasswordSession(
        email: _emailController.text.trim(),
        confirmationCode: _codeController.text.trim(),
      ),
    );
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
            const AuthHeader(
              compact: true,
              title: 'Nhập mã\nOTP',
              subtitle:
                  'Nhập mã OTP đã được gửi tới email để tiếp tục đặt mật khẩu mới.',
              icon: Icons.pin_outlined,
            ),
            const SizedBox(height: 24),
            const AuthTimeline(
              activeIndex: 1,
              steps: [
                AuthTimelineStep(icon: Icons.check_rounded, label: 'Email'),
                AuthTimelineStep(icon: Icons.pin_outlined, label: 'OTP'),
                AuthTimelineStep(
                  icon: Icons.lock_reset_outlined,
                  label: 'Mật khẩu mới',
                ),
              ],
            ),
            const SizedBox(height: 28),
            AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    _EmailChip(email: _emailController.text),
                    const SizedBox(height: 18),
                  ],
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
                    onChanged: (_) => _updateContinueState(),
                  ),
                  const SizedBox(height: 22),
                  AuthPrimaryButton(
                    label: 'Tiếp tục',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _canContinue ? _continueToPassword : null,
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

class ResetPasswordNewPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordNewPasswordScreen({super.key, required this.session});

  final ResetPasswordSession? session;

  @override
  ConsumerState<ResetPasswordNewPasswordScreen> createState() =>
      _ResetPasswordNewPasswordScreenState();
}

class _ResetPasswordNewPasswordScreenState
    extends ConsumerState<ResetPasswordNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_updateSubmitState);
    _confirmPasswordController.addListener(_updateSubmitState);
  }

  @override
  void dispose() {
    _passwordController.removeListener(_updateSubmitState);
    _confirmPasswordController.removeListener(_updateSubmitState);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _updateSubmitState() {
    final next =
        widget.session != null &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty;
    if (next != _canSubmit) {
      setState(() => _canSubmit = next);
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    final session = widget.session;
    if (session == null || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .confirmResetPassword(
            email: session.email,
            confirmationCode: session.confirmationCode,
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
    final session = widget.session;

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/forgot-password');
      });
      return const AuthScaffold(child: SizedBox.shrink());
    }

    return AuthScaffold(
      leading: Align(
        alignment: Alignment.centerLeft,
        child: IconButton.filledTonal(
          tooltip: l10n.back,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(
              '/reset-password?email=${Uri.encodeComponent(session.email)}',
            );
          },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthHeader(
              compact: true,
              title: 'Tạo mật khẩu\nmới',
              subtitle: 'Thiết lập mật khẩu mới cho tài khoản của bạn.',
              icon: Icons.lock_reset_outlined,
            ),
            const SizedBox(height: 24),
            const AuthTimeline(
              activeIndex: 2,
              steps: [
                AuthTimelineStep(icon: Icons.check_rounded, label: 'Email'),
                AuthTimelineStep(icon: Icons.check_rounded, label: 'OTP'),
                AuthTimelineStep(
                  icon: Icons.lock_reset_outlined,
                  label: 'Mật khẩu mới',
                ),
              ],
            ),
            const SizedBox(height: 28),
            AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _EmailChip(email: session.email),
                  const SizedBox(height: 20),
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

class _EmailChip extends StatelessWidget {
  const _EmailChip({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AuthColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AuthColors.primary.withValues(alpha: 0.15)),
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
            Flexible(
              child: Text(
                email,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AuthColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
