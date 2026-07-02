import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_state.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/data/aws_application_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/application_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/recommendations/application/job_recommendation_providers.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  test(
    'AI rate limit falls back locally and skips repeated AI calls during cooldown',
    () async {
      var aiCalls = 0;
      final client = MockClient((request) async {
        aiCalls++;
        return http.Response(
          jsonEncode({
            'error': {
              'code': 'AI_RATE_LIMITED',
              'message': 'Please retry in 20s.',
            },
          }),
          429,
        );
      });

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (_, _) => AuthState.authenticated(_profile),
          ),
          activeJobsProvider.overrideWith((_) async => [_job]),
          activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
          applicationRepositoryProvider.overrideWithValue(
            _FakeApplicationRepository(),
          ),
          jobRecommendationHttpClientProvider.overrideWithValue(client),
          jobRecommendationAuthTokenProvider.overrideWith((_) async => 'token'),
          jobRecommendationNowProvider.overrideWithValue(
            () => DateTime(2026, 7, 2, 9),
          ),
        ],
      );
      addTearDown(container.dispose);

      final first = await container.read(
        personalizedJobRecommendationsProvider.future,
      );
      expect(aiCalls, 1);
      expect(first.map((item) => item.job.id), contains('job-1'));

      container.invalidate(personalizedJobRecommendationsProvider);
      final second = await container.read(
        personalizedJobRecommendationsProvider.future,
      );

      expect(aiCalls, 1);
      expect(second.map((item) => item.job.id), contains('job-1'));
    },
  );

  test(
    'missing auth token uses local fallback without calling AI API',
    () async {
      var aiCalls = 0;
      final client = MockClient((request) async {
        aiCalls++;
        return http.Response('{}', 200);
      });

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (_, _) => AuthState.authenticated(_profile),
          ),
          activeJobsProvider.overrideWith((_) async => [_job]),
          activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
          applicationRepositoryProvider.overrideWithValue(
            _FakeApplicationRepository(),
          ),
          jobRecommendationHttpClientProvider.overrideWithValue(client),
          jobRecommendationAuthTokenProvider.overrideWith((_) async => null),
        ],
      );
      addTearDown(container.dispose);

      final recommendations = await container.read(
        personalizedJobRecommendationsProvider.future,
      );

      expect(aiCalls, 0);
      expect(recommendations.map((item) => item.job.id), contains('job-1'));
    },
  );
}

const _profile = AuthUserProfile(
  userId: 'candidate-1',
  username: 'candidate',
  role: AppRole.candidate,
  email: 'candidate@example.com',
  fullName: 'Nguyen An',
  kycCompleted: true,
  profileCompleted: true,
  skills: ['Pha chế'],
);

final _job = JobPost(
  id: 'job-1',
  idJob: 'job-1',
  employerId: 'employer-1',
  employerName: 'Katinat',
  title: 'Nhân viên pha chế',
  jobType: JobPostType.partTime,
  location: 'Thủ Đức',
  salary: '25.000 VNĐ/giờ',
  shiftTime: '',
  description: 'Pha chế đồ uống',
  tags: const ['Pha chế'],
  postedAt: DateTime(2026, 7, 1),
);

class _FakeApplicationRepository implements ApplicationRepository {
  @override
  Future<List<Map<String, dynamic>>> getCandidateCVs(String userId) async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> getCandidateApplications(
    String userId,
  ) async {
    return const [];
  }

  @override
  Future<void> archiveApplicationChat({
    required String applicationId,
    required DateTime archivedAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> confirmApplicationCompletion({
    required String applicationId,
    required DateTime confirmedAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCandidateCV({required String userId, String? cvId}) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> submitApplication({
    required String jobId,
    required String cvUrl,
    required String cvFilename,
    required ApplicationNotificationDetails notification,
    Map<String, dynamic>? extraFields,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> submitCandidateRating({
    required String applicationId,
    required Map<String, dynamic> candidateRating,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateApplicationChat({
    required String applicationId,
    required String status,
    required List<Map<String, dynamic>> chatMessages,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    Map<String, dynamic> extraFields = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> uploadCandidateCV({
    required String userId,
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
  }) {
    throw UnimplementedError();
  }
}
