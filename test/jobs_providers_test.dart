import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/data/aws_job_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_repository.dart';

void main() {
  test('quick jobs expose the shared API failure', () async {
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        jobRepositoryProvider.overrideWithValue(_FailingJobRepository()),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      activeQuickJobsProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);

    await expectLater(
      container.read(activeQuickJobsProvider.future),
      throwsA(isA<JobRepositoryException>()),
    );
  });
}

class _FailingJobRepository implements JobRepository {
  @override
  Future<List<JobPost>> getActiveJobs() async => const [];

  @override
  Future<List<JobPost>> getActiveQuickJobs() {
    throw const JobRepositoryException('Service unavailable');
  }

  @override
  Future<void> incrementJobViews(
    String jobId, {
    required bool isQuickJob,
  }) async {}
}
