import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/auth_failure.dart';
import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/auth_form_fields.dart';
import '../../auth/presentation/widgets/auth_header.dart';
import '../../auth/presentation/widgets/auth_primary_button.dart';
import '../../auth/presentation/widgets/auth_scaffold.dart';
import '../../auth/presentation/widgets/auth_text_field.dart';
import '../../auth/presentation/widgets/password_requirement_list.dart';
import '../../auth/presentation/widgets/password_strength_bar.dart';

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
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _currentPasswordController,
      _newPasswordController,
      _confirmPasswordController,
    ]) {
      controller.addListener(_updateSubmitState);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _currentPasswordController,
      _newPasswordController,
      _confirmPasswordController,
    ]) {
      controller.removeListener(_updateSubmitState);
      controller.dispose();
    }
    super.dispose();
  }

  void _updateSubmitState() {
    final next =
        _currentPasswordController.text.isNotEmpty &&
        _newPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty;
    if (next != _canSubmit) {
      setState(() => _canSubmit = next);
    } else {
      setState(() {});
    }
  }

  String? _validateNewPassword(String? value) {
    final strings = AppLocalizations.of(context);
    final requiredError = requiredTextValidator(
      value,
      message: strings.passwordRequired,
    );
    if (requiredError != null) {
      return requiredError;
    }

    if (value == _currentPasswordController.text) {
      return strings.passwordReuseNotAllowed;
    }

    return cognitoPasswordValidator(
      value,
      requiredMessage: strings.passwordRequired,
      weakPasswordMessage: strings.weakPassword,
    );
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _newPasswordController.text) {
      return AppLocalizations.of(context).passwordMismatch;
    }
    return requiredTextValidator(
      value,
      message: AppLocalizations.of(context).passwordRequired,
    );
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

    return AuthScaffold(
      leading: Align(
        alignment: Alignment.centerLeft,
        child: IconButton.filledTonal(
          tooltip: strings.back,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeader(
              compact: true,
              title: strings.changePassword,
              subtitle:
                  'Cập nhật mật khẩu mới để bảo vệ tài khoản ứng viên của bạn.',
              icon: Icons.password_rounded,
            ),
            const SizedBox(height: 28),
            AuthFormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    controller: _currentPasswordController,
                    label: strings.currentPassword,
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscureCurrentPassword,
                    textInputAction: TextInputAction.next,
                    validator: (value) => requiredTextValidator(
                      value,
                      message: strings.passwordRequired,
                    ),
                    suffix: IconButton(
                      tooltip: _obscureCurrentPassword
                          ? strings.text('showPassword')
                          : strings.text('hidePassword'),
                      icon: Icon(
                        _obscureCurrentPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () =>
                            _obscureCurrentPassword = !_obscureCurrentPassword,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _newPasswordController,
                    label: strings.newPassword,
                    icon: Icons.lock_reset_outlined,
                    obscureText: _obscureNewPassword,
                    textInputAction: TextInputAction.next,
                    validator: _validateNewPassword,
                    suffix: IconButton(
                      tooltip: _obscureNewPassword
                          ? strings.text('showPassword')
                          : strings.text('hidePassword'),
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setState(
                        () => _obscureNewPassword = !_obscureNewPassword,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PasswordStrengthBar(password: _newPasswordController.text),
                  const SizedBox(height: 12),
                  PasswordRequirementList(
                    password: _newPasswordController.text,
                  ),
                  const SizedBox(height: 16),
                  AuthTextField(
                    controller: _confirmPasswordController,
                    label: strings.confirmNewPassword,
                    icon: Icons.verified_user_outlined,
                    obscureText: _obscureConfirmPassword,
                    validator: _validateConfirmPassword,
                    suffix: IconButton(
                      tooltip: _obscureConfirmPassword
                          ? strings.text('showPassword')
                          : strings.text('hidePassword'),
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
                  const SizedBox(height: 24),
                  AuthPrimaryButton(
                    label: strings.changePassword,
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
