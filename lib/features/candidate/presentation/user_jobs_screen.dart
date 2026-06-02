import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../data/mock_job_posts.dart';
import 'user_location_screen.dart';
import 'widgets/availability_card.dart';
import 'widgets/job_post_card.dart';
import 'widgets/location_card.dart';

class UserJobsScreen extends StatefulWidget {
  const UserJobsScreen({super.key});

  @override
  State<UserJobsScreen> createState() => _UserJobsScreenState();
}

class _UserJobsScreenState extends State<UserJobsScreen> {
  bool _isAvailable = false;

  void _toggleAvailability(bool value) {
    setState(() {
      _isAvailable = value;
    });
    // TODO: Save candidate availability to DynamoDB when backend is ready.
  }

  void _openLocation() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const UserLocationScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final filters = [
      l10n.todayShift,
      l10n.partTime,
      l10n.nearby,
      l10n.highSalary,
    ];
    final jobs = mockJobPosts;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.postsTabTitle, // Matches the tab title 'Bài đăng'
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(l10n.text('jobsIntro')),
            const SizedBox(height: 16),
            AvailabilityCard(
              isAvailable: _isAvailable,
              onChanged: _toggleAvailability,
            ),
            const SizedBox(height: 12),
            LocationCard(onUpdateLocation: _openLocation),
            const SizedBox(height: 20),
            SearchBar(
              hintText: l10n.text('searchJobs'),
              leading: const Icon(Icons.search),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.text('searchWillBeBuilt'))),
                );
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in filters)
                  FilterChip(
                    label: Text(filter),
                    selected: false,
                    onSelected: (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.format('filterWillBeBuilt', {
                              'filter': filter,
                            }),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // Header for jobs list
            Text(
              l10n.text('recommendedJobs'),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            // Jobs feed
            if (jobs.isEmpty)
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.work_off_outlined, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        l10n.text('noJobsFound'),
                        style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: jobs.length,
                separatorBuilder: (context, index) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  return JobPostCard(job: jobs[index]);
                },
              ),
          ],
        ),
      ),
    );
  }
}
