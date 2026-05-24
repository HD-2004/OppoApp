import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../application/urgent_shift_providers.dart';
import 'shift_card.dart';

class WorkerMarketplaceScreen extends ConsumerWidget {
  const WorkerMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('urgentJobs'))),
      body: const WorkerMarketplaceScreenBody(),
    );
  }
}

class WorkerMarketplaceScreenBody extends ConsumerWidget {
  const WorkerMarketplaceScreenBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(openUrgentJobsProvider);

    return SafeArea(
      child: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(
              child: Text(AppLocalizations.of(context).noJobsFound),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final job = jobs[index];
              return ShiftCard(
                job: job,
                onTap: () => context.go('/jobs/${job.jobId}'),
              );
            },
          );
        },
      ),
    );
  }
}
