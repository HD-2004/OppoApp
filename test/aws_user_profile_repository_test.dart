import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oppo_temp_jobs/features/auth/data/aws_user_profile_repository.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  test(
    'new profile payload always stores candidate role in the mobile app',
    () {
      final payload = buildProfileCreatePayload(
        userId: 'user-1',
        email: 'candidate@example.com',
        fullName: 'Candidate',
        role: AppRole.candidate,
        createdAt: DateTime.parse('2026-06-14T08:00:00Z'),
      );

      expect(payload['role'], 'user');
    },
  );

  test('new profile payload defaults missing role to candidate', () {
    final payload = buildProfileCreatePayload(
      userId: 'unknown-1',
      email: 'unknown@example.com',
      fullName: 'Unknown',
      role: null,
      createdAt: DateTime.parse('2026-06-14T08:00:00Z'),
    );

    expect(payload['role'], 'user');
  });

  test('new profile payload stores date of birth when provided', () {
    final payload = buildProfileCreatePayload(
      userId: 'candidate-1',
      email: 'candidate@example.com',
      fullName: 'Candidate',
      role: AppRole.candidate,
      dateOfBirth: '2000-01-05',
      createdAt: DateTime.parse('2026-06-14T08:00:00Z'),
    );

    expect(payload['dateOfBirth'], '2000-01-05');
  });

  test('builds quick job activation notification for admin review', () {
    final submittedAt = DateTime.parse('2026-07-13T08:00:00Z');
    final payload = buildQuickJobActivationRequestNotification(
      user: _profile(),
      submittedAt: submittedAt,
    );

    expect(payload['type'], 'quick_job_activation_request');
    expect(payload['recipientId'], 'admin');
    expect(payload['recipientRole'], 'admin');
    expect(payload['senderId'], 'candidate-1');
    expect(payload['senderName'], 'Nguyen An');
    expect(payload['actionUrl'], '/admin/candidates');
    expect(payload['data'], {
      'candidateId': 'candidate-1',
      'candidateName': 'Nguyen An',
      'candidateEmail': 'candidate@example.com',
      'verificationStatus': 'SUBMITTED',
      'verificationSubmittedAt': '2026-07-13T08:00:00.000Z',
    });
  });

  test(
    'submits quick job activation request to admin notification backend',
    () async {
      final submittedAt = DateTime.parse('2026-07-13T08:00:00Z');
      final requests = <http.Request>[];
      final repository = AwsUserProfileRepository(
        client: MockClient((request) async {
          requests.add(request);

          if (request.url.host == 'notifications.example.com') {
            expect(request.method, 'POST');
            expect(request.url.path, '/notifications');
            expect(request.headers['Authorization'], isNull);

            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['type'], 'quick_job_activation_request');
            expect(body['recipientRole'], 'admin');
            expect(body['senderId'], 'candidate-1');
            return http.Response(jsonEncode({'success': true}), 201);
          }

          if (request.url.host == 'profile.example.com') {
            expect(request.method, 'PUT');
            expect(request.url.path, '/profile/candidate-1');
            expect(request.headers['Authorization'], 'Bearer id-token');
            throw http.ClientException('Failed to fetch', request.url);
          }

          return http.Response('Not found', 404);
        }),
        tokenProvider: () async => 'id-token',
        profileBaseUrl: 'https://profile.example.com',
        notificationsBaseUrl: 'https://notifications.example.com',
        nowProvider: () => submittedAt,
      );

      final updated = await repository.submitVerificationRequest(
        userId: 'candidate-1',
        currentProfile: _profile(),
      );

      expect(updated.verificationStatus, 'SUBMITTED');
      expect(updated.updatedAt, submittedAt);
      expect(
        requests.map((request) => request.url.host).toList(growable: false),
        ['notifications.example.com', 'profile.example.com'],
      );
    },
  );
}

AuthUserProfile _profile() {
  return const AuthUserProfile(
    userId: 'candidate-1',
    username: 'candidate',
    role: AppRole.candidate,
    email: 'candidate@example.com',
    fullName: 'Nguyen An',
    kycCompleted: true,
    profileCompleted: true,
    verificationStatus: 'PENDING',
  );
}
