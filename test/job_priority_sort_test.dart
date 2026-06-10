import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';

void main() {
  test('sorts jobs by backend visibility score then created date', () {
    final newestLowPriority = _job(
      id: 'newest-low',
      postedAt: DateTime.parse('2026-06-08T10:00:00Z'),
      visibilityScore: 1,
    );
    final olderHighPriority = _job(
      id: 'older-high',
      postedAt: DateTime.parse('2026-06-07T10:00:00Z'),
      visibilityScore: 9,
    );
    final newerHighPriority = _job(
      id: 'newer-high',
      postedAt: DateTime.parse('2026-06-08T09:00:00Z'),
      visibilityScore: 9,
    );

    final sorted = sortJobsByVisibilityThenCreatedAt([
      newestLowPriority,
      olderHighPriority,
      newerHighPriority,
    ]);

    expect(sorted.map((job) => job.id), [
      'newer-high',
      'older-high',
      'newest-low',
    ]);
  });
}

JobPost _job({
  required String id,
  required DateTime postedAt,
  required double visibilityScore,
}) {
  return JobPost(
    id: id,
    idJob: id,
    employerId: 'employer-$id',
    employerName: 'Employer',
    title: 'Job $id',
    jobType: JobPostType.fullTime,
    location: 'TP.HCM',
    salary: 'Thỏa thuận',
    shiftTime: '',
    description: '',
    tags: const [],
    postedAt: postedAt,
    visibilityScore: visibilityScore,
  );
}
