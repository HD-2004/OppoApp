import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/features/candidate/data/support_feedback_repository.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  test('submits feedback using the shared web API contract', () async {
    late http.Request capturedRequest;
    final client = MockClient((request) async {
      capturedRequest = request;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {'id': 'feed-1234'},
        }),
        200,
      );
    });
    final repository = SupportFeedbackRepository(
      client: client,
      apiBaseUrl: 'https://example.com/prod',
      tokenProvider: () async => 'id-token',
    );
    const user = AuthUserProfile(
      userId: 'candidate-1',
      username: 'candidate@example.com',
      role: AppRole.candidate,
      email: 'candidate@example.com',
      fullName: 'Nguyen Van A',
      kycCompleted: true,
      profileCompleted: true,
    );

    await repository.submit(
      category: 'bug',
      comment: '  Không thể mở trang công việc  ',
      user: user,
      attachments: [
        SupportAttachment(
          bytes: Uint8List.fromList([1, 2, 3]),
          mimeType: 'image/png',
        ),
      ],
    );

    expect(capturedRequest.url.toString(), 'https://example.com/prod/feedback');
    expect(capturedRequest.headers['Authorization'], 'Bearer id-token');

    final payload = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
    expect(payload['category'], 'bug');
    expect(payload['comment'], 'Không thể mở trang công việc');
    expect(payload['userId'], 'candidate-1');
    expect(payload['userName'], 'Nguyen Van A');
    expect(payload['userEmail'], 'candidate@example.com');
    expect(payload['userRole'], 'candidate');
    expect(payload['imageUrls'], ['data:image/png;base64,AQID']);
  });

  test('throws the backend message when feedback submission fails', () async {
    final repository = SupportFeedbackRepository(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Feedback table is unavailable'}),
          503,
        ),
      ),
      apiBaseUrl: 'https://example.com/prod',
      tokenProvider: () async => null,
    );
    const user = AuthUserProfile(
      userId: 'candidate-1',
      username: 'candidate@example.com',
      role: AppRole.candidate,
      email: 'candidate@example.com',
      fullName: 'Nguyen Van A',
      kycCompleted: true,
      profileCompleted: true,
    );

    expect(
      () => repository.submit(category: 'other', comment: 'Help', user: user),
      throwsA(
        isA<SupportFeedbackException>().having(
          (error) => error.message,
          'message',
          'Feedback table is unavailable',
        ),
      ),
    );
  });
}
