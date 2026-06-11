import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/recommendations/application/job_recommendation_service.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  const service = JobRecommendationService();

  test('ranks jobs using profile skills, title, location and history', () {
    final recommendations = service.recommend(
      profile: _profile,
      jobs: [
        _job(
          id: 'matching',
          title: 'Flutter Developer',
          location: 'Ho Chi Minh',
          tags: const ['Flutter', 'Dart'],
        ),
        _job(
          id: 'other',
          title: 'Nhân viên phục vụ',
          location: 'Ha Noi',
          tags: const ['F&B'],
        ),
      ],
      applications: const [
        {'jobId': 'old', 'jobTitle': 'Mobile Developer', 'status': 'completed'},
      ],
    );

    expect(recommendations.first.job.id, 'matching');
    expect(recommendations.first.matchScore, greaterThan(60));
    expect(recommendations.first.reasons.join(' '), contains('Khớp kỹ năng'));
  });

  test('does not recommend a job the candidate already applied to', () {
    final recommendations = service.recommend(
      profile: _profile,
      jobs: [
        _job(
          id: 'applied',
          title: 'Flutter Developer',
          location: 'Ho Chi Minh',
          tags: const ['Flutter'],
        ),
        _job(
          id: 'new',
          title: 'Dart Developer',
          location: 'Ho Chi Minh',
          tags: const ['Dart'],
        ),
      ],
      applications: const [
        {
          'jobId': 'applied',
          'jobTitle': 'Flutter Developer',
          'status': 'pending',
        },
      ],
    );

    expect(
      recommendations.map((item) => item.job.id),
      isNot(contains('applied')),
    );
    expect(recommendations.map((item) => item.job.id), contains('new'));
  });
}

const _profile = AuthUserProfile(
  userId: 'candidate-1',
  username: 'candidate',
  role: AppRole.candidate,
  email: 'candidate@example.com',
  fullName: 'Nguyen An',
  kycCompleted: true,
  profileCompleted: true,
  title: 'Mobile Developer',
  location: 'Ho Chi Minh City',
  skills: ['Flutter', 'Dart'],
);

JobPost _job({
  required String id,
  required String title,
  required String location,
  required List<String> tags,
}) {
  return JobPost(
    id: id,
    idJob: id,
    employerId: 'employer',
    employerName: 'Oppo',
    title: title,
    jobType: JobPostType.fullTime,
    location: location,
    salary: '20 triệu',
    shiftTime: '',
    description: '$title ${tags.join(' ')}',
    tags: tags,
    postedAt: DateTime(2026, 6, 10),
  );
}
