import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
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
