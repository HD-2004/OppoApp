import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../domain/job_post.dart';

class UserJobDetailScreen extends StatelessWidget {
  const UserJobDetailScreen({super.key, required this.job});

  final JobPost job;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.jobDetails)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(job.employerName),
              const SizedBox(height: 16),
              Text(l10n.text('searchWillBeBuilt')),
            ],
          ),
        ),
      ),
    );
  }
}
