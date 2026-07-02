import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/aws_job_repository.dart';
import '../domain/job_post.dart';
import '../domain/job_recruitment_window.dart';

final jobListingsRefreshIntervalProvider = Provider<Duration?>(
  (_) => null,
);

final activeJobsProvider = FutureProvider.autoDispose<List<JobPost>>((
  ref,
) async {
  _scheduleJobListingsRefresh(ref);
  final repository = ref.watch(jobRepositoryProvider);
  final jobs = await repository.getActiveJobs();
  return sortJobsByVisibilityThenCreatedAt(filterRecruitableJobs(jobs));
});

final activeQuickJobsProvider = FutureProvider.autoDispose<List<JobPost>>((
  ref,
) async {
  _scheduleJobListingsRefresh(ref);
  final repository = ref.watch(jobRepositoryProvider);
  final jobs = await repository.getActiveQuickJobs();
  return sortJobsByVisibilityThenCreatedAt(filterRecruitableJobs(jobs));
});

void _scheduleJobListingsRefresh(Ref ref) {
  final interval = ref.watch(jobListingsRefreshIntervalProvider);
  if (interval == null || interval <= Duration.zero) {
    return;
  }

  final timer = Timer.periodic(interval, (_) {
    ref.invalidateSelf(asReload: true);
  });
  ref.onDispose(timer.cancel);
}

List<JobPost> filterRecruitableJobs(List<JobPost> jobs, {DateTime? now}) {
  final referenceTime = now ?? DateTime.now();
  return jobs
      .where((job) => isJobPostRecruitable(job, now: referenceTime))
      .toList(growable: false);
}

List<JobPost> sortJobsByVisibilityThenCreatedAt(List<JobPost> jobs) {
  final sorted = [...jobs];
  sorted.sort((a, b) {
    final scoreComparison = b.visibilityScore.compareTo(a.visibilityScore);
    if (scoreComparison != 0) {
      return scoreComparison;
    }
    return b.postedAt.compareTo(a.postedAt);
  });
  return sorted;
}
