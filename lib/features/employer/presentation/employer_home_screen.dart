import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../auth/application/auth_controller.dart';
import '../../urgent_jobs/presentation/employer_dashboard_screen.dart';

class EmployerHomeScreen extends ConsumerWidget {
  const EmployerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.employer),
        actions: [
          IconButton(
            tooltip: l10n.signOut,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const EmployerDashboardScreenBody(),
    );
  }
}
