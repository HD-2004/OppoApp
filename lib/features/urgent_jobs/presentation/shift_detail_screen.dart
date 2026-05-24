import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../application/urgent_shift_providers.dart';
import '../domain/urgent_shift_job.dart';
import 'job_status_chip.dart';

class ShiftDetailScreen extends ConsumerWidget {
  const ShiftDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(openUrgentJobsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.jobDetails)),
      body: SafeArea(
        child: jobsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          data: (jobs) {
            final matches = jobs.where((item) => item.jobId == jobId);
            final job = matches.isEmpty ? null : matches.first;
            if (job == null) {
              return Center(child: Text(l10n.noJobsFound));
            }
            return _ShiftDetailBody(job: job);
          },
        ),
      ),
    );
  }
}

class _ShiftDetailBody extends ConsumerStatefulWidget {
  const _ShiftDetailBody({required this.job});

  final UrgentShiftJob job;

  @override
  ConsumerState<_ShiftDetailBody> createState() => _ShiftDetailBodyState();
}

class _ShiftDetailBodyState extends ConsumerState<_ShiftDetailBody> {
  bool _isClaiming = false;

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final pay = NumberFormat.decimalPattern().format(job.payAmount);
    final formatter = DateFormat('EEE, MMM d - HH:mm');
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                job.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            JobStatusChip(status: job.status),
          ],
        ),
        const SizedBox(height: 16),
        _DetailTile(icon: Icons.category_outlined, label: job.category),
        _DetailTile(icon: Icons.place_outlined, label: job.address),
        _DetailTile(
          icon: Icons.schedule,
          label:
              '${formatter.format(job.startTime)} to ${formatter.format(job.endTime)}',
        ),
        _DetailTile(
          icon: Icons.payments_outlined,
          label: '$pay ${job.currency} ${l10n.salary}',
        ),
        _DetailTile(
          icon: Icons.groups_outlined,
          label: '${job.requiredWorkers - job.acceptedWorkers}',
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _isClaiming ? null : _claim,
          icon: _isClaiming
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.flash_on_outlined),
          label: Text(l10n.apply),
        ),
      ],
    );
  }

  Future<void> _claim() async {
    setState(() => _isClaiming = true);
    try {
      final booking = await ref
          .read(urgentShiftRepositoryProvider)
          .claimShift(jobId: widget.job.jobId, workerId: 'worker-demo');
      if (mounted) {
        context.go('/bookings/${booking.bookingId}');
      }
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isClaiming = false);
      }
    }
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
