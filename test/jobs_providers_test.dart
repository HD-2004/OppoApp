import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/data/aws_job_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_repository.dart';
import 'package:oppo_temp_jobs/features/jobs/presentation/controllers/jobs_controller.dart';

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

  test('job listings do not auto-refresh by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(jobListingsRefreshIntervalProvider), isNull);
  });

  test('quick jobs refresh automatically while watched', () async {
    final repository = _SequencedJobRepository(
      activeQuickJobs: [
        const <JobPost>[],
        [_job('new-quick', jobType: JobPostType.urgent, isQuickJob: true)],
      ],
    );
    final container = ProviderContainer(
      overrides: [
        jobRepositoryProvider.overrideWithValue(repository),
        jobListingsRefreshIntervalProvider.overrideWithValue(
          const Duration(milliseconds: 10),
        ),
      ],
    );
    addTearDown(container.dispose);

    final observed = <List<String>>[];
    final subscription = container.listen(activeQuickJobsProvider, (
      previous,
      next,
    ) {
      next.whenData((jobs) {
        observed.add(jobs.map((job) => job.idJob).toList(growable: false));
      });
    }, fireImmediately: true);
    addTearDown(subscription.close);

    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(observed, contains(equals(const <String>[])));
    expect(observed, contains(equals(const ['new-quick'])));
  });

  test('jobs controller follows refreshed job listings', () async {
    final repository = _SequencedJobRepository(
      activeQuickJobs: [
        const <JobPost>[],
        [
          _job(
            'controller-quick',
            jobType: JobPostType.urgent,
            isQuickJob: true,
          ),
        ],
      ],
    );
    final container = ProviderContainer(
      overrides: [
        jobRepositoryProvider.overrideWithValue(repository),
        jobListingsRefreshIntervalProvider.overrideWithValue(
          const Duration(milliseconds: 10),
        ),
      ],
    );
    addTearDown(container.dispose);

    final observed = <List<String>>[];
    final subscription = container.listen(jobsControllerProvider, (
      previous,
      next,
    ) {
      next.whenData((state) {
        observed.add(
          state.urgentJobs.map((job) => job.idJob).toList(growable: false),
        );
      });
    }, fireImmediately: true);
    addTearDown(subscription.close);

    await container.read(jobsControllerProvider.future);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(observed, contains(equals(const <String>[])));
    expect(observed, contains(equals(const ['controller-quick'])));
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

class _SequencedJobRepository implements JobRepository {
  _SequencedJobRepository({this.activeQuickJobs = const [<JobPost>[]]});

  final List<List<JobPost>> activeQuickJobs;
  var _activeQuickJobsCallCount = 0;

  @override
  Future<List<JobPost>> getActiveJobs() async => const [];

  @override
  Future<List<JobPost>> getActiveQuickJobs() async {
    final index = _activeQuickJobsCallCount.clamp(
      0,
      activeQuickJobs.length - 1,
    );
    _activeQuickJobsCallCount += 1;
    return activeQuickJobs[index];
  }

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
  JobPostType jobType = JobPostType.partTime,
  bool isQuickJob = false,
}) {
  return JobPost(
    id: id,
    idJob: id,
    employerId: 'employer-1',
    employerName: 'Công ty Demo',
    title: 'Nhân viên phục vụ',
    jobType: jobType,
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
    isQuickJob: isQuickJob,
  );
}
