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

final jobRecommendationHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final jobRecommendationAuthTokenProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  try {
    final cognitoPlugin = Amplify.Auth.getPlugin(AmplifyAuthCognito.pluginKey);
    final session = await cognitoPlugin.fetchAuthSession();
    final tokens = session.userPoolTokensResult.valueOrNull;
    return tokens?.idToken.raw;
  } catch (e) {
    safePrint('Error getting AI recommendation auth token: $e');
    return null;
  }
});

final jobRecommendationNowProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

final jobRecommendationRateLimitCooldownProvider = Provider<Duration>(
  (_) => const Duration(minutes: 1),
);

final jobRecommendationAiCooldownUntilProvider =
    NotifierProvider<JobRecommendationAiCooldownUntil, DateTime?>(
      JobRecommendationAiCooldownUntil.new,
    );

class JobRecommendationAiCooldownUntil extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void clear() {
    state = null;
  }

  void setUntil(DateTime value) {
    state = value;
  }
}

final personalizedJobRecommendationsProvider =
    FutureProvider.autoDispose<List<JobRecommendation>>((ref) async {
      final profile = ref.watch(authControllerProvider).asData?.value.user;
      if (profile == null) return const [];

      final standardJobsFuture = ref.read(activeJobsProvider.future);
      final quickJobsFuture = ref.read(activeQuickJobsProvider.future);
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

      final client = ref.watch(jobRecommendationHttpClientProvider);
      bool useFallback = false;
      final apiRecommendations = <JobRecommendation>[];
      final now = ref.read(jobRecommendationNowProvider)();
      final cooldownUntil = ref.read(jobRecommendationAiCooldownUntilProvider);

      if (cooldownUntil != null && now.isBefore(cooldownUntil)) {
        safePrint('Skipping AI recommend-jobs API during rate-limit cooldown.');
        useFallback = true;
      } else {
        const apiBaseUrl =
            'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod';

        try {
          final token = await ref.watch(
            jobRecommendationAuthTokenProvider.future,
          );
          if (token == null) {
            safePrint(
              'Skipping AI recommend-jobs API because auth token is unavailable.',
            );
            useFallback = true;
          } else {
            final response = await client
                .post(
                  Uri.parse('$apiBaseUrl/candidate/recommend-jobs'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $token',
                  },
                  body: jsonEncode({'language': 'vi'}),
                )
                .timeout(const Duration(seconds: 15));

            if (response.statusCode == 200) {
              ref
                  .read(jobRecommendationAiCooldownUntilProvider.notifier)
                  .clear();
              final payload = jsonDecode(response.body);
              final recs = payload['recommendations'] as List?;
              if (recs != null) {
                apiRecommendations.addAll(
                  mapApiJobRecommendationsToJobs(
                    rawRecommendations: recs,
                    jobs: jobs,
                  ),
                );
                if (recs.isNotEmpty && apiRecommendations.isEmpty) {
                  safePrint(
                    'AI recommend-jobs API returned job ids that did not match loaded app jobs.',
                  );
                  useFallback = true;
                }
              } else {
                useFallback = true;
              }
            } else if (_isAiRecommendationRateLimited(response)) {
              final cooldown = _rateLimitCooldownFromResponse(
                response,
                fallback: ref.read(jobRecommendationRateLimitCooldownProvider),
              );
              final nextAllowedAt = now.add(cooldown);
              ref
                  .read(jobRecommendationAiCooldownUntilProvider.notifier)
                  .setUntil(nextAllowedAt);
              safePrint(
                'AI recommend-jobs API rate limited; using fallback until '
                '${nextAllowedAt.toIso8601String()}.',
              );
              useFallback = true;
            } else {
              safePrint(
                'AI recommend-jobs API returned status ${response.statusCode}.',
              );
              useFallback = true;
            }
          }
        } catch (e, stack) {
          safePrint('Error calling AI recommend-jobs API: $e\n$stack');
          useFallback = true;
        }
      }

      if (useFallback) {
        safePrint('Falling back to local rule-based JobRecommendationService');
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

bool _isAiRecommendationRateLimited(http.Response response) {
  if (response.statusCode == 429) {
    return true;
  }
  return response.body.contains('AI_RATE_LIMITED');
}

Duration _rateLimitCooldownFromResponse(
  http.Response response, {
  required Duration fallback,
}) {
  final match = RegExp(
    r'retry in\s+([0-9]+(?:\.[0-9]+)?)s',
    caseSensitive: false,
  ).firstMatch(response.body);
  final seconds = double.tryParse(match?.group(1) ?? '');
  if (seconds == null || seconds <= 0) {
    return fallback;
  }
  return Duration(milliseconds: (seconds * 1000).ceil());
}
