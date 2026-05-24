import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  AppRole _role = AppRole.candidate;
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
              role: _role,
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.signUp)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _fullNameController,
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
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
                        controller: _passwordController,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        decoration: authInputDecoration(
                          label: l10n.password,
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
                          label: l10n.confirmPassword,
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
                      const SizedBox(height: 16),
                      Text(
                        l10n.text('role'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<AppRole>(
                        segments: [
                          ButtonSegment(
                            value: AppRole.candidate,
                            icon: const Icon(Icons.person_search_outlined),
                            label: Text(l10n.text('userCandidate')),
                          ),
                          ButtonSegment(
                            value: AppRole.employer,
                            icon: const Icon(Icons.business_center_outlined),
                            label: Text(l10n.text('employerNtd')),
                          ),
                        ],
                        selected: {_role},
                        onSelectionChanged: (selection) {
                          setState(() => _role = selection.first);
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSubmitting ? null : _submit,
                          icon: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1),
                          label: Text(l10n.signUp),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
