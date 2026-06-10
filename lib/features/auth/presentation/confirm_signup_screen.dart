import 'dart:async';

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
import 'widgets/otp_input_field.dart';

class ConfirmSignUpScreen extends ConsumerStatefulWidget {
  const ConfirmSignUpScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<ConfirmSignUpScreen> createState() =>
      _ConfirmSignUpScreenState();
}

class _ConfirmSignUpScreenState extends ConsumerState<ConfirmSignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _codeController = TextEditingController();
  bool _isSubmitting = false;
  bool _isResending = false;
  bool _canSubmit = false;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
    _emailController.addListener(_updateSubmitState);
    _codeController.addListener(_updateSubmitState);
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.removeListener(_updateSubmitState);
    _codeController.removeListener(_updateSubmitState);
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _updateSubmitState() {
    final next =
        _emailController.text.trim().isNotEmpty &&
        _codeController.text.trim().length == 6;
    if (next != _canSubmit) setState(() => _canSubmit = next);
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _resendCountdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendCountdown = 0);
        return;
      }
      if (mounted) setState(() => _resendCountdown--);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .confirmSignUp(
            email: _emailController.text.trim(),
            confirmationCode: _codeController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.text('confirmSignUpSuccess'))),
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

  Future<void> _resendCode() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError(l10n.emailRequired);
      return;
    }
    setState(() => _isResending = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resendSignUpCode(email: email);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.text('resendCodeSuccess'))));
        _startCountdown();
      }
    } on AuthFailure catch (f) {
      _showError(f.message);
    } catch (_) {
      _showError(l10n.unknownError);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final emailDisplay = _emailController.text.isNotEmpty
        ? _emailController.text
        : null;

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
              title: 'Xác nhận\ntài khoản',
              subtitle: 'Nhập mã 6 chữ số đã được gửi về email của bạn.',
              icon: Icons.verified_outlined,
            ),
            const SizedBox(height: 28),

            // ── Form card ─────────────────────────────────────────
            AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Email field or display
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
                    const SizedBox(height: 20),
                  ] else ...[
                    // Email chip display
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
                              emailDisplay ?? '',
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
                    const SizedBox(height: 20),
                  ],

                  // OTP hint
                  Text(
                    'Nhập mã xác nhận',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AuthColors.textSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),

                  // OTP boxes — larger, more premium
                  OtpInputField(
                    controller: _codeController,
                    onChanged: (_) => _updateSubmitState(),
                  ),
                  const SizedBox(height: 8),

                  // Countdown row
                  Center(
                    child: _resendCountdown > 0
                        ? Text(
                            'Gửi lại mã sau ${_resendCountdown}s',
                            style: TextStyle(
                              fontSize: 12,
                              color: AuthColors.textSecondary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : TextButton.icon(
                            onPressed: _isResending ? null : _resendCode,
                            icon: _isResending
                                ? const SizedBox.square(
                                    dimension: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(l10n.resendCode),
                            style: TextButton.styleFrom(
                              foregroundColor: AuthColors.primary,
                            ),
                          ),
                  ),
                  const SizedBox(height: 22),
                  AuthPrimaryButton(
                    label: l10n.confirm,
                    icon: Icons.check_circle_outline_rounded,
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
