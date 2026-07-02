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

  test('maps web recommendation ids from standard and quick job payloads', () {
    final standard = _job(
      id: 'JOB-1',
      title: 'Nhân viên pha chế trà sữa',
      location: 'Quận 2',
      tags: const ['Pha chế'],
    );
    final quick = _job(
      id: 'quick-QJOB-1',
      idJob: 'QJOB-1',
      title: 'Nhân viên pha chế rượu',
      location: 'Thủ Đức',
      tags: const ['Tuyển gấp'],
      isQuickJob: true,
    );

    final recommendations = mapApiJobRecommendationsToJobs(
      rawRecommendations: const [
        {
          'jobID': 'QJOB-1',
          'matchScore': 95,
          'matchReason': 'Gần vị trí của bạn',
        },
        {'idJob': 'JOB-1', 'score': 80, 'reason': 'Khớp kỹ năng pha chế'},
      ],
      jobs: [standard, quick],
    );

    expect(recommendations.map((item) => item.job.idJob), ['QJOB-1', 'JOB-1']);
    expect(recommendations.map((item) => item.matchScore), [95, 80]);
    expect(recommendations.first.reasons, ['Gần vị trí của bạn']);
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
  String? idJob,
  required String title,
  required String location,
  required List<String> tags,
  bool isQuickJob = false,
}) {
  return JobPost(
    id: id,
    idJob: idJob ?? id,
    employerId: 'employer',
    employerName: 'Oppo',
    title: title,
    jobType: isQuickJob ? JobPostType.urgent : JobPostType.fullTime,
    location: location,
    salary: '20 triệu',
    shiftTime: '',
    description: '$title ${tags.join(' ')}',
    tags: tags,
    postedAt: DateTime(2026, 6, 10),
    isQuickJob: isQuickJob,
  );
}
