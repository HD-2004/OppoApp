import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../candidate/application/jobs_providers.dart';
import '../../candidate/data/aws_application_repository.dart';
import '../../candidate/domain/job_post.dart';
import '../domain/job_recommendation.dart';
import 'job_recommendation_service.dart';

final jobRecommendationServiceProvider = Provider<JobRecommendationService>(
  (_) => const JobRecommendationService(),
);

final personalizedJobRecommendationsProvider =
    FutureProvider.autoDispose<List<JobRecommendation>>((ref) async {
      final profile = ref.watch(authControllerProvider).asData?.value.user;
      if (profile == null) return const [];

      final standardJobsFuture = ref.watch(activeJobsProvider.future);
      final quickJobsFuture = ref.watch(activeQuickJobsProvider.future);
      final repository = ref.watch(applicationRepositoryProvider);

      final results = await Future.wait<Object>([
        standardJobsFuture,
        quickJobsFuture,
        repository.getCandidateCVs(profile.userId),
        repository.getCandidateApplications(profile.userId),
      ]);

      final jobs = <JobPost>[
        ...results[0] as List<JobPost>,
        ...results[1] as List<JobPost>,
      ];

      return ref
          .read(jobRecommendationServiceProvider)
          .recommend(
            profile: profile,
            jobs: jobs,
            cvs: results[2] as List<Map<String, dynamic>>,
            applications: results[3] as List<Map<String, dynamic>>,
          );
    });
