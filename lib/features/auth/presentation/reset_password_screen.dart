import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/auth_failure.dart';
import '../../../core/localization/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_form_fields.dart';

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

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
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
          .confirmResetPassword(
            email: _emailController.text,
            confirmationCode: _codeController.text,
            newPassword: _passwordController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.text('resetPasswordSuccess'))),
        );
        context.go('/login');
      }
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.resetPassword)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: authInputDecoration(
                      label: l10n.email,
                      icon: Icons.mail_outline,
                    ),
                    validator: (value) => requiredTextValidator(
                      value,
                      message: l10n.emailRequired,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    decoration: authInputDecoration(
                      label: l10n.verificationCode,
                      icon: Icons.verified_outlined,
                    ),
                    validator: (value) => requiredTextValidator(
                      value,
                      message: l10n.text('requiredField'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: authInputDecoration(
                      label: l10n.newPassword,
                      icon: Icons.lock_outline,
                    ),
                    validator: (value) => cognitoPasswordValidator(
                      value,
                      requiredMessage: l10n.passwordRequired,
                      weakPasswordMessage: l10n.weakPassword,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: true,
                    decoration: authInputDecoration(
                      label: l10n.confirmNewPassword,
                      icon: Icons.lock_reset_outlined,
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
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.password_outlined),
                    label: Text(l10n.resetPassword),
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
