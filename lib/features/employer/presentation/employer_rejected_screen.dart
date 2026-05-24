import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';

class EmployerRejectedScreen extends ConsumerWidget {
  const EmployerRejectedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('rejectedTitle'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.block_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    l10n.isVietnamese
                        ? 'Tài khoản nhà tuyển dụng của bạn không được duyệt.'
                        : 'Your employer account was not approved.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.isVietnamese
                        ? 'Vui lòng liên hệ bộ phận hỗ trợ nếu bạn cần kiểm tra lại hồ sơ doanh nghiệp.'
                        : 'Please contact support if you need your business profile reviewed again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.support_agent_outlined),
                    label: Text(l10n.text('contactSupport')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                    icon: const Icon(Icons.logout),
                    label: Text(l10n.signOut),
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
