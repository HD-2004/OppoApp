import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../../core/localization/app_localizations.dart';
import '../data/mock_job_posts.dart';
import 'widgets/home_filter_chips.dart';
import 'widgets/job_post_card.dart';

class UserHomeFeedScreen extends ConsumerStatefulWidget {
  const UserHomeFeedScreen({super.key});

  @override
  ConsumerState<UserHomeFeedScreen> createState() => _UserHomeFeedScreenState();
}

class _UserHomeFeedScreenState extends ConsumerState<UserHomeFeedScreen> {
  Future<void> _refreshFeed() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider).asData?.value.user;
    final displayName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : l10n.text('candidate').toLowerCase();
    final jobs = mockJobPosts;
    final filters = [
      l10n.text('nearby'),
      l10n.text('highSalary'),
      l10n.text('todayShift'),
      l10n.partTime,
      l10n.text('urgentJobs'),
    ];

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refreshFeed,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.isEmpty ? 4 : jobs.length + 3,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.format('homeGreeting', {'name': displayName}),
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.text('homeSubtitle'),
                          style: textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              );
            }

            if (index == 1) {
              return SearchBar(
                hintText: l10n.text('searchJobsOrEmployers'),
                leading: const Icon(Icons.search),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.text('searchWillBeBuilt'))),
                  );
                },
              );
            }

            if (index == 2) {
              return HomeFilterChips(filters: filters);
            }

            if (jobs.isEmpty) {
              return const _EmptyFeedState();
            }

            return JobPostCard(job: jobs[index - 3]);
          },
        ),
      ),
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.work_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text(
            l10n.text('noJobsFound'),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(l10n.text('tryChangeFilters'), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
