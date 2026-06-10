import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/home/presentation/widgets/home_current_job_section.dart';

void main() {
  test('resolves the latest current job using the same statuses as web', () {
    final older = DateTime.utc(2026, 6, 8);
    final newer = DateTime.utc(2026, 6, 9);
    final jobs = [_job('QJOB-1', 'Ca cũ'), _job('QJOB-2', 'Ca hiện tại')];

    final current = resolveHomeCurrentJob(
      applications: [
        {
          'applicationId': 'APP-1',
          'jobId': 'QJOB-1',
          'status': 'accepted',
          'appliedAt': older.toIso8601String(),
        },
        {
          'applicationId': 'APP-2',
          'jobId': 'QJOB-2',
          'status': 'completed_pending_candidate',
          'appliedAt': newer.toIso8601String(),
        },
      ],
      jobs: jobs,
    );

    expect(current?.applicationId, 'APP-2');
    expect(current?.job.title, 'Ca hiện tại');
    expect(current?.isPendingCandidateConfirmation, isTrue);
    expect(current?.isAwaitingCandidateRating, isFalse);
  });

  test('completed application without candidate rating waits for rating', () {
    final current = resolveHomeCurrentJob(
      applications: [
        {
          'applicationId': 'APP-1',
          'jobId': 'QJOB-1',
          'status': 'completed',
          'appliedAt': '2026-06-09T08:00:00Z',
        },
      ],
      jobs: [_job('QJOB-1', 'Ca đã xong')],
    );

    expect(current?.isAwaitingCandidateRating, isTrue);
  });

  test('ignores completed applications that already have candidate rating', () {
    final current = resolveHomeCurrentJob(
      applications: [
        {
          'applicationId': 'APP-1',
          'jobId': 'QJOB-1',
          'status': 'completed',
          'candidateRating': {'overall': 5},
          'appliedAt': '2026-06-09T08:00:00Z',
        },
      ],
      jobs: [_job('QJOB-1', 'Đã hoàn thành')],
    );

    expect(current, isNull);
  });
}

JobPost _job(String id, String title) {
  return JobPost(
    id: 'quick-$id',
    idJob: id,
    employerId: 'employer-1',
    employerName: 'Katinat Quận Cam',
    title: title,
    jobType: JobPostType.urgent,
    location: 'Thủ Đức, TP.HCM',
    salary: '100.000 VNĐ/giờ',
    shiftTime: '08:00 - 12:00',
    description: '',
    tags: const [],
    postedAt: DateTime.utc(2026, 6, 8),
    isQuickJob: true,
  );
}
