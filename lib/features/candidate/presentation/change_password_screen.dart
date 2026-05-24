import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/auth_failure.dart';
import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateRequiredPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context).passwordRequired;
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context).passwordRequired;
    }
    if (value == _currentPasswordController.text) {
      return AppLocalizations.of(context).weakPassword;
    }
    final hasMinLength = value.length >= 8;
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(value);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(value);
    final hasNumber = RegExp(r'[0-9]').hasMatch(value);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(value);
    if (!hasMinLength ||
        !hasUppercase ||
        !hasLowercase ||
        !hasNumber ||
        !hasSymbol) {
      return AppLocalizations.of(context).weakPassword;
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppLocalizations.of(context).passwordRequired;
    }
    if (value != _newPasswordController.text) {
      return AppLocalizations.of(context).passwordMismatch;
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      if (!mounted) {
        return;
      }
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).text('changePasswordSuccess'),
          ),
        ),
      );
      Navigator.of(context).pop();
    } on AuthFailure catch (failure) {
      if (!mounted) {
        return;
      }
      final message = switch (failure.code) {
        'not_authorized' => AppLocalizations.of(context).wrongCurrentPassword,
        'invalid_password' => AppLocalizations.of(context).weakPassword,
        'limit_exceeded' => AppLocalizations.of(context).unknownError,
        'network' => AppLocalizations.of(context).networkError,
        _ => AppLocalizations.of(context).unknownError,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.changePassword)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: strings.currentPassword,
                  border: const OutlineInputBorder(),
                ),
                validator: _validateRequiredPassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: strings.newPassword,
                  helperText: strings.weakPassword,
                  border: const OutlineInputBorder(),
                ),
                validator: _validateNewPassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: strings.confirmNewPassword,
                  border: const OutlineInputBorder(),
                ),
                validator: _validateConfirmPassword,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(strings.changePassword),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
