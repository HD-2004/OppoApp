import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/data/aws_job_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_repository.dart';

void main() {
  test(
    'filterRecruitableJobs keeps only jobs inside the recruitment window',
    () {
      final now = DateTime(2026, 7, 15, 23, 59);
      final active = _job(
        'active',
        recruitmentStartDate: DateTime(2026, 7, 1),
        recruitmentEndDate: DateTime(2026, 7, 15),
      );
      final expiredByDate = _job(
        'expired-date',
        recruitmentStartDate: DateTime(2026, 7, 1),
        recruitmentEndDate: DateTime(2026, 7, 14),
      );
      final future = _job(
        'future',
        recruitmentStartDate: DateTime(2026, 7, 16),
        recruitmentEndDate: DateTime(2026, 7, 20),
      );
      final expiredByStatus = _job(
        'expired-status',
        recruitmentStartDate: DateTime(2026, 7, 1),
        recruitmentEndDate: DateTime(2026, 7, 30),
        status: 'expired',
      );
      final archived = _job(
        'archived',
        recruitmentStartDate: DateTime(2026, 7, 1),
        recruitmentEndDate: DateTime(2026, 7, 30),
        status: 'archived',
      );
      final missingDates = _job('missing-dates');

      final visible = filterRecruitableJobs([
        active,
        expiredByDate,
        future,
        expiredByStatus,
        archived,
        missingDates,
      ], now: now);

      expect(visible.map((job) => job.idJob), ['active', 'missing-dates']);
    },
  );

  test('active jobs provider filters stale jobs before sorting', () async {
    final now = DateTime.now();
    final activeOlderLowScore = _job(
      'active-low',
      recruitmentStartDate: now.subtract(const Duration(days: 1)),
      recruitmentEndDate: now.add(const Duration(days: 2)),
      postedAt: now.subtract(const Duration(days: 3)),
      visibilityScore: 1,
    );
    final activeNewerHighScore = _job(
      'active-high',
      recruitmentStartDate: now.subtract(const Duration(days: 1)),
      recruitmentEndDate: now.add(const Duration(days: 2)),
      postedAt: now.subtract(const Duration(days: 10)),
      visibilityScore: 10,
    );
    final expired = _job(
      'expired',
      recruitmentStartDate: now.subtract(const Duration(days: 10)),
      recruitmentEndDate: now.subtract(const Duration(days: 1)),
      postedAt: now,
      visibilityScore: 999,
    );

    final container = ProviderContainer(
      overrides: [
        jobRepositoryProvider.overrideWithValue(
          _SuccessfulJobRepository(
            activeJobs: [expired, activeOlderLowScore, activeNewerHighScore],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final jobs = await container.read(activeJobsProvider.future);

    expect(jobs.map((job) => job.idJob), ['active-high', 'active-low']);
  });

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

class _SuccessfulJobRepository implements JobRepository {
  const _SuccessfulJobRepository({this.activeJobs = const []});

  final List<JobPost> activeJobs;

  @override
  Future<List<JobPost>> getActiveJobs() async => activeJobs;

  @override
  Future<List<JobPost>> getActiveQuickJobs() async => const [];

  @override
  Future<void> incrementJobViews(
    String jobId, {
    required bool isQuickJob,
  }) async {}
}

JobPost _job(
  String id, {
  DateTime? recruitmentStartDate,
  DateTime? recruitmentEndDate,
  String status = 'active',
  DateTime? postedAt,
  double visibilityScore = 0,
}) {
  return JobPost(
    id: id,
    idJob: id,
    employerId: 'employer-1',
    employerName: 'Công ty Demo',
    title: 'Nhân viên phục vụ',
    jobType: JobPostType.partTime,
    location: 'Quận 1',
    salary: '30.000 VNĐ/giờ',
    shiftTime: '08:00 - 12:00',
    description: 'Phục vụ khách hàng.',
    tags: const ['F&B'],
    postedAt: postedAt ?? DateTime(2026, 6, 1),
    recruitmentStartDate: recruitmentStartDate,
    recruitmentEndDate: recruitmentEndDate,
    status: status,
    visibilityScore: visibilityScore,
  );
}
