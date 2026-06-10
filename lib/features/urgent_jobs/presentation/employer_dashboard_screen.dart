import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../employer_packages/application/featured_employer_package_providers.dart';
import '../../employer_packages/presentation/widgets/package_status_card.dart';
import '../application/urgent_shift_providers.dart';
import 'shift_card.dart';

class EmployerDashboardScreen extends ConsumerWidget {
  const EmployerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('urgentJobs'))),
      body: const EmployerDashboardScreenBody(),
    );
  }
}

class EmployerDashboardScreenBody extends ConsumerWidget {
  const EmployerDashboardScreenBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(employerUrgentJobsProvider);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      child: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        data: (jobs) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PackageStatusCard(
              onRenew: () => context.push('/employer/packages'),
            ),
            _PackagesMenuTile(onTap: () => context.push('/employer/packages')),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.employer,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () {},
                  tooltip: l10n.text('urgentJobs'),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...jobs.map(
              (job) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ShiftCard(job: job, onTap: () {}),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackagesMenuTile extends ConsumerWidget {
  const _PackagesMenuTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.workspace_premium_outlined, color: colorScheme.primary),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Packages',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: 'Làm mới gói',
              onPressed: () {
                ref.invalidate(currentPackageStatusProvider);
                ref.invalidate(packagePlansProvider);
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
