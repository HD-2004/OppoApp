import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/auth_failure.dart';
import '../../../core/localization/app_localizations.dart';
import '../application/auth_controller.dart';
import 'auth_form_fields.dart';

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

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
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
          .confirmSignUp(
            email: _emailController.text,
            confirmationCode: _codeController.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.text('confirmSignUpSuccess'))),
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
      }
    } on AuthFailure catch (failure) {
      _showError(failure.message);
    } catch (error) {
      _showError(l10n.unknownError);
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
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
      appBar: AppBar(title: Text(l10n.confirmSignUp)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
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
                      icon: Icons.verified_user_outlined,
                    ),
                    validator: (value) => requiredTextValidator(
                      value,
                      message: l10n.text('requiredField'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(l10n.confirm),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _isResending ? null : _resendCode,
                    icon: _isResending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(l10n.resendCode),
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
