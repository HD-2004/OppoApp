import '../domain/job_post.dart';

abstract class JobRepository {
  Future<List<JobPost>> getActiveJobs();
  Future<List<JobPost>> getActiveQuickJobs();
  Future<void> incrementJobViews(String jobId, {required bool isQuickJob});
}
