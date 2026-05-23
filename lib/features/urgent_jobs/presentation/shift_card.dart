import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/urgent_shift_job.dart';
import 'job_status_chip.dart';

class ShiftCard extends StatelessWidget {
  const ShiftCard({super.key, required this.job, required this.onTap});

  final UrgentShiftJob job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('EEE, HH:mm').format(job.startTime);
    final pay = NumberFormat.decimalPattern().format(job.payAmount);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  JobStatusChip(status: job.status),
                ],
              ),
              const SizedBox(height: 8),
              _FactRow(icon: Icons.schedule, text: time),
              _FactRow(icon: Icons.place_outlined, text: job.address),
              _FactRow(
                icon: Icons.groups_outlined,
                text: '${job.acceptedWorkers}/${job.requiredWorkers} accepted',
              ),
              const SizedBox(height: 10),
              Text(
                '$pay ${job.currency}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
