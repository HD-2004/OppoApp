import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/auth_failure.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/domain/app_role.dart';
import '../../candidate/presentation/policy_terms_screen.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import '../data/check_email_service.dart';
import '../domain/candidate_age_policy.dart';
import 'auth_form_fields.dart';
import 'widgets/auth_colors.dart';
import 'widgets/auth_footer_link.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/password_requirement_list.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  AuthProvider? _socialProviderSubmitting;
  bool _canSubmit = false;
  // Lỗi inline hiển thị ngay dưới ô Email (từ check-email API).
  String? _emailError;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _fullNameController,
      _emailController,
      _dateOfBirthController,
      _passwordController,
      _confirmPasswordController,
    ]) {
      c.addListener(_updateSubmitState);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _fullNameController,
      _emailController,
      _dateOfBirthController,
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
        _fullNameController.text.trim().isNotEmpty &&
        _emailController.text.trim().isNotEmpty &&
        _dateOfBirthController.text.trim().isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _confirmPasswordController.text.isNotEmpty;
    if (next != _canSubmit) {
      setState(() => _canSubmit = next);
    } else {
      setState(() {});
    }
    // Xóa lỗi inline khi user thay đổi email
    if (_emailError != null) setState(() => _emailError = null);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    final dateOfBirth =
        CandidateAgePolicy.normalizeDateOfBirth(_dateOfBirthController.text) ??
        _dateOfBirthController.text.trim();
    setState(() {
      _isSubmitting = true;
      _emailError = null;
    });
    try {
      // ── Bước 1: kiểm tra email trước khi gọi signUp ───────────────────────
      final checker = const CheckEmailService();
      final result = await checker.check(_emailController.text.trim());

      if (result.isGoogle) {
        // Email đã đăng ký qua Google
        setState(() {
          _emailError = 'Email đã tồn tại, vui lòng sử dụng gmail khác.';
        });
        return;
      }

      if (result.isNative) {
        // Email đã đăng ký bằng email/password — hiện link điều hướng
        setState(() {
          _emailError = _kNativeExistsMessage;
        });
        return;
      }

      // ── Bước 2: email chưa tồn tại → gọi signUp bình thường ──────────────
      await ref
          .read(authControllerProvider.notifier)
          .register(
            RegisterRequest(
              fullName: _fullNameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
              role: AppRole.candidate,
              dateOfBirth: dateOfBirth,
            ),
          );
    } on CheckEmailException catch (e) {
      // Lỗi gọi check-email API — vẫn cho phép tiếp tục (Cognito là lớp phòng vệ cuối)
      _showError(e.message);
      try {
        await ref
            .read(authControllerProvider.notifier)
            .register(
              RegisterRequest(
                fullName: _fullNameController.text.trim(),
                email: _emailController.text.trim(),
                password: _passwordController.text,
                role: AppRole.candidate,
                dateOfBirth: dateOfBirth,
              ),
            );
      } on AuthFailure catch (f) {
        _showError(f.message);
      } catch (_) {
        _showError(l10n.unknownError);
      }
    } on AuthFailure catch (f) {
      // Lớp phòng vệ cuối — lỗi từ Cognito Pre Sign-up Lambda hoặc Amplify
      _showError(f.message);
    } catch (_) {
      _showError(l10n.unknownError);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Marker để widget build nhận biết cần hiển thị dạng "có link điều hướng"
  static const String _kNativeExistsMessage = '__native_exists__';

  Future<void> _selectDateOfBirth() async {
    var initialDate = DateTime.now().subtract(
      const Duration(days: 365 * CandidateAgePolicy.minimumAge),
    );
    final existing = CandidateAgePolicy.parseDate(_dateOfBirthController.text);
    if (existing != null) {
      initialDate = existing;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;

    _dateOfBirthController.text = CandidateAgePolicy.formatDisplayDate(picked);
    _updateSubmitState();
  }

  Future<void> _submitSocial(AuthProvider provider) async {
    if (_isSubmitting || _socialProviderSubmitting != null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _socialProviderSubmitting = provider);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signInWithSocialProvider(provider);
    } on AuthFailure catch (f) {
      _showError(f.message);
    } catch (e) {
      _showError('${l10n.unknownError}\n[debug] $e');
    } finally {
      if (mounted) setState(() => _socialProviderSubmitting = null);
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
      child: _RegisterFormStep(
        formKey: _formKey,
        fullNameController: _fullNameController,
        emailController: _emailController,
        dateOfBirthController: _dateOfBirthController,
        passwordController: _passwordController,
        confirmPasswordController: _confirmPasswordController,
        obscurePassword: _obscurePassword,
        obscureConfirmPassword: _obscureConfirmPassword,
        isSubmitting: _isSubmitting,
        socialProviderSubmitting: _socialProviderSubmitting,
        canSubmit: _canSubmit,
        emailError: _emailError,
        onTogglePassword: () =>
            setState(() => _obscurePassword = !_obscurePassword),
        onToggleConfirmPassword: () =>
            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
        onSelectDateOfBirth: _selectDateOfBirth,
        onSubmit: _submit,
        onSubmitSocial: _submitSocial,
        onNavigateToLogin: () => context.go('/login'),
        l10n: l10n,
      ),
    );
  }
}

class _RegisterFormStep extends StatelessWidget {
  const _RegisterFormStep({
    required this.formKey,
    required this.fullNameController,
    required this.emailController,
    required this.dateOfBirthController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.isSubmitting,
    required this.socialProviderSubmitting,
    required this.canSubmit,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onSelectDateOfBirth,
    required this.onSubmit,
    required this.onSubmitSocial,
    required this.l10n,
    this.emailError,
    this.onNavigateToLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController dateOfBirthController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final bool isSubmitting;
  final AuthProvider? socialProviderSubmitting;
  final bool canSubmit;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onSelectDateOfBirth;
  final VoidCallback onSubmit;
  final ValueChanged<AuthProvider> onSubmitSocial;
  final AppLocalizations l10n;

  /// Lỗi inline hiển thị dưới ô Email (null = không có lỗi).
  final String? emailError;

  /// Điều hướng sang màn đăng nhập (dùng khi email đã có tài khoản native).
  final VoidCallback? onNavigateToLogin;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            compact: true,
            title: 'Tạo tài khoản ứng viên',
            subtitle: 'Điền thông tin để bắt đầu hành trình.',
          ),
          const SizedBox(height: 28),
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthTextField(
                  controller: fullNameController,
                  label: l10n.fullName,
                  icon: Icons.badge_outlined,
                  textInputAction: TextInputAction.next,
                  validator: (v) => requiredTextValidator(
                    v,
                    message: l10n.text('requiredField'),
                  ),
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: emailController,
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
                // Lỗi inline từ check-email API
                if (emailError != null &&
                    emailError != _RegisterScreenState._kNativeExistsMessage)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 14),
                    child: Text(
                      emailError!,
                      style: const TextStyle(
                        color: AuthColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                // Trường hợp đặc biệt: email đã có tài khoản native → hiện link đăng nhập
                if (emailError == _RegisterScreenState._kNativeExistsMessage)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8),
                    child: Row(
                      children: [
                        const Text(
                          'Email này đã được đăng ký. ',
                          style: TextStyle(
                            color: AuthColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        GestureDetector(
                          onTap: onNavigateToLogin,
                          child: const Text(
                            'Đăng nhập ngay?',
                            style: TextStyle(
                              color: AuthColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: dateOfBirthController,
                  label: 'Ngày sinh',
                  icon: Icons.calendar_month_outlined,
                  hintText: 'dd/MM/yyyy',
                  keyboardType: TextInputType.datetime,
                  textInputAction: TextInputAction.next,
                  validator: CandidateAgePolicy.validateDateOfBirth,
                  suffix: IconButton(
                    tooltip: 'Chọn ngày sinh',
                    icon: const Icon(Icons.event_outlined),
                    onPressed: onSelectDateOfBirth,
                  ),
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: passwordController,
                  label: l10n.password,
                  icon: Icons.lock_outline_rounded,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.next,
                  validator: (v) => cognitoPasswordValidator(
                    v,
                    requiredMessage: l10n.passwordRequired,
                    weakPasswordMessage: l10n.weakPassword,
                  ),
                  suffix: IconButton(
                    tooltip: obscurePassword
                        ? l10n.text('showPassword')
                        : l10n.text('hidePassword'),
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: onTogglePassword,
                  ),
                ),
                const SizedBox(height: 12),
                PasswordRequirementList(password: passwordController.text),
                const SizedBox(height: 14),
                AuthTextField(
                  controller: confirmPasswordController,
                  label: l10n.confirmPassword,
                  icon: Icons.lock_reset_outlined,
                  obscureText: obscureConfirmPassword,
                  validator: (v) {
                    if (v != passwordController.text) {
                      return l10n.passwordMismatch;
                    }
                    return requiredTextValidator(
                      v,
                      message: l10n.passwordRequired,
                    );
                  },
                  suffix: IconButton(
                    tooltip: obscureConfirmPassword
                        ? l10n.text('showPassword')
                        : l10n.text('hidePassword'),
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: onToggleConfirmPassword,
                  ),
                ),
                const SizedBox(height: 22),
                AuthPrimaryButton(
                  label: 'Tạo tài khoản',
                  icon: Icons.person_add_alt_1_rounded,
                  isLoading: isSubmitting,
                  onPressed: canSubmit && socialProviderSubmitting == null
                      ? onSubmit
                      : null,
                ),
                const SizedBox(height: 18),
                const AuthSectionDivider(label: 'Hoặc'),
                const SizedBox(height: 14),
                AuthSocialButton(
                  label: 'Google',
                  iconText: 'G',
                  accentColor: const Color(0xFFE04F3D),
                  isLoading: socialProviderSubmitting == AuthProvider.google,
                  onPressed: socialProviderSubmitting == null && !isSubmitting
                      ? () => onSubmitSocial(AuthProvider.google)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AuthFooterLink(
            text: 'Đã có tài khoản?',
            actionText: 'Đăng nhập',
            onPressed: () => context.go('/login'),
          ),
          const SizedBox(height: 4),
          const PolicyInlineLinks(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
