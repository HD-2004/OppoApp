import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/aws_job_repository.dart';
import '../domain/job_post.dart';

final activeJobsProvider = FutureProvider.autoDispose<List<JobPost>>((ref) async {
  final repository = ref.watch(jobRepositoryProvider);
  return repository.getActiveJobs();
});

final activeQuickJobsProvider = FutureProvider.autoDispose<List<JobPost>>((ref) async {
  final repository = ref.watch(jobRepositoryProvider);
  return repository.getActiveQuickJobs();
});
