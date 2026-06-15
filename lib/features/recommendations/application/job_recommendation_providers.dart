import 'dart:convert';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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

      final client = http.Client();
      bool useFallback = false;
      final apiRecommendations = <JobRecommendation>[];

      try {
        final cognitoPlugin = Amplify.Auth.getPlugin(
          AmplifyAuthCognito.pluginKey,
        );
        final session = await cognitoPlugin.fetchAuthSession();
        final tokens = session.userPoolTokensResult.valueOrNull;
        final token = tokens?.idToken.raw;

        const apiBaseUrl =
            'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod';

        final response = await client.post(
          Uri.parse('$apiBaseUrl/candidate/recommend-jobs'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'language': 'vi'}),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final payload = jsonDecode(response.body);
          final recs = payload['recommendations'] as List?;
          if (recs != null) {
            final Map<String, JobPost> jobMap = {};
            for (final job in jobs) {
              jobMap[job.idJob] = job;
              jobMap[job.id] = job;
            }

            for (final item in recs) {
              if (item is! Map) continue;
              final jobId = item['jobId']?.toString();
              final matchScore = item['matchScore'] is num
                  ? (item['matchScore'] as num).toInt()
                  : 50;
              final matchReason = item['matchReason']?.toString() ?? '';

              final matchedJob = jobMap[jobId];
              if (matchedJob != null) {
                apiRecommendations.add(
                  JobRecommendation(
                    job: matchedJob,
                    matchScore: matchScore,
                    reasons: [matchReason],
                  ),
                );
              }
            }
          } else {
            useFallback = true;
          }
        } else {
          safePrint(
            'AI recommend-jobs API returned status ${response.statusCode}: ${response.body}',
          );
          useFallback = true;
        }
      } catch (e, stack) {
        safePrint('Error calling AI recommend-jobs API: $e\n$stack');
        useFallback = true;
      } finally {
        client.close();
      }

      if (useFallback) {
        safePrint(
          'Falling back to local rule-based JobRecommendationService',
        );
        return ref
            .read(jobRecommendationServiceProvider)
            .recommend(
              profile: profile,
              jobs: jobs,
              cvs: results[2] as List<Map<String, dynamic>>,
              applications: results[3] as List<Map<String, dynamic>>,
            );
      }

      return apiRecommendations;
    });
