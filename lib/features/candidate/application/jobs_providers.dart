import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/aws_job_repository.dart';
import '../domain/job_post.dart';

final activeJobsProvider = FutureProvider.autoDispose<List<JobPost>>((
  ref,
) async {
  final repository = ref.watch(jobRepositoryProvider);
  final jobs = await repository.getActiveJobs();
  return sortJobsByVisibilityThenCreatedAt(jobs);
});

final activeQuickJobsProvider = FutureProvider.autoDispose<List<JobPost>>((
  ref,
) async {
  final repository = ref.watch(jobRepositoryProvider);
  final jobs = await repository.getActiveQuickJobs();
  return sortJobsByVisibilityThenCreatedAt(jobs);
});

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
