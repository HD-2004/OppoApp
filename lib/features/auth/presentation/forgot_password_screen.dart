import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/auth_failure.dart';
import '../../../core/localization/app_localizations.dart';
import '../../candidate/presentation/policy_terms_screen.dart';
import '../application/auth_controller.dart';
import 'auth_form_fields.dart';
import 'widgets/auth_header.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/auth_timeline.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.email});

  final String? email;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isSubmitting = false;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email ?? '');
    _emailController.addListener(_updateSubmitState);
    _updateSubmitState();
  }

  @override
  void dispose() {
    _emailController.removeListener(_updateSubmitState);
    _emailController.dispose();
    super.dispose();
  }

  void _updateSubmitState() {
    final next = _emailController.text.trim().isNotEmpty;
    if (next != _canSubmit) setState(() => _canSubmit = next);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _isSubmitting = true);
    try {
      final email = _emailController.text.trim();
      await ref
          .read(authControllerProvider.notifier)
          .resetPassword(email: email);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.text('verificationSent'))));
        context.go('/reset-password?email=${Uri.encodeComponent(email)}');
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
              title: 'Khôi phục\nmật khẩu',
              subtitle:
                  'Nhập email đã đăng ký để nhận mã xác nhận và tạo mật khẩu mới.',
              icon: Icons.lock_reset_outlined,
            ),
            const SizedBox(height: 24),

            // ── Timeline 3 bước ──────────────────────────────────
            AuthTimeline(
              activeIndex: 0,
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
                  const _StepInfo(
                    icon: Icons.mail_outline_rounded,
                    title: 'Bước 1: Nhập email',
                    subtitle:
                        'Mã xác nhận sẽ được gửi về địa chỉ email của bạn.',
                  ),
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 22),
                  AuthPrimaryButton(
                    label: 'Gửi mã xác nhận',
                    icon: Icons.mark_email_read_outlined,
                    isLoading: _isSubmitting,
                    onPressed: _canSubmit ? _submit : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(l10n.text('backToSignIn')),
            ),
            const SizedBox(height: 4),
            const PolicyInlineLinks(),
          ],
        ),
      ),
    );
  }
}

class _StepInfo extends StatelessWidget {
  const _StepInfo({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF10B981), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
