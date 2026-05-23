import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/urgent_shift_providers.dart';
import 'shift_card.dart';

class WorkerMarketplaceScreen extends ConsumerWidget {
  const WorkerMarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(openUrgentJobsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Open urgent shifts')),
      body: SafeArea(
        child: jobsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          data: (jobs) {
            if (jobs.isEmpty) {
              return const Center(child: Text('No open shifts right now.'));
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
      ),
    );
  }
}
