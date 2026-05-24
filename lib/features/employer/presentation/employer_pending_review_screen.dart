import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';

class EmployerPendingReviewScreen extends ConsumerWidget {
  const EmployerPendingReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('pendingReviewTitle'))),
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
                  const Icon(Icons.hourglass_top_outlined, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    l10n.isVietnamese
                        ? 'Tài khoản nhà tuyển dụng của bạn đang được xét duyệt.'
                        : 'Your employer account is under review.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
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
