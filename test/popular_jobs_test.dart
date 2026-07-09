import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/jobs/application/popular_jobs.dart';

void main() {
  test('sorts popular jobs by applicants, reputation, rating, then newest', () {
    final oldest = _job(
      id: 'oldest',
      applicants: 4,
      employerReputationScore: 50,
      candidateRatingScore: 4.5,
      postedAt: DateTime(2026, 7, 1),
    );
    final highestApplicants = _job(
      id: 'highest-applicants',
      applicants: 8,
      employerReputationScore: 10,
      candidateRatingScore: 1,
      postedAt: DateTime(2026, 7, 1),
    );
    final bestReputation = _job(
      id: 'best-reputation',
      applicants: 4,
      employerReputationScore: 90,
      candidateRatingScore: 1,
      postedAt: DateTime(2026, 7, 1),
    );
    final bestRating = _job(
      id: 'best-rating',
      applicants: 4,
      employerReputationScore: 50,
      candidateRatingScore: 4.9,
      postedAt: DateTime(2026, 7, 1),
    );
    final newest = _job(
      id: 'newest',
      applicants: 4,
      employerReputationScore: 50,
      candidateRatingScore: 4.5,
      postedAt: DateTime(2026, 7, 9),
    );

    final result = sortJobsByPopularity([
      oldest,
      bestRating,
      highestApplicants,
      newest,
      bestReputation,
    ]);

    expect(result.map((job) => job.id), [
      'highest-applicants',
      'best-reputation',
      'best-rating',
      'newest',
      'oldest',
    ]);
  });
}

JobPost _job({
  required String id,
  required int applicants,
  required double employerReputationScore,
  required double candidateRatingScore,
  required DateTime postedAt,
}) {
  return JobPost(
    id: id,
    idJob: id,
    employerId: 'employer-$id',
    employerName: 'Employer $id',
    title: 'Job $id',
    jobType: JobPostType.partTime,
    location: 'Quan 1',
    salary: '35.000 VND/gio',
    shiftTime: '08:00 - 12:00',
    description: 'Popular job',
    tags: const ['F&B'],
    postedAt: postedAt,
    applicants: applicants,
    employerReputationScore: employerReputationScore,
    candidateRatingScore: candidateRatingScore,
  );
}
