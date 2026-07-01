import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oppo_temp_jobs/features/candidate/data/aws_ai_interview_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/ai_interview_repository.dart';

void main() {
  test('screenCv posts to shared cv-ai with Cognito auth header', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return _jsonResponse({
        'score': 88,
        'result': 'pass',
        'strengths': ['Phù hợp'],
        'weaknesses': <String>[],
        'reason': 'Đạt vòng 1.',
      });
    });
    final repository = AwsAiInterviewRepository(
      client: client,
      tokenProvider: () async => 'id-token',
      baseUrl: 'https://cv-ai.example.com/prod',
    );

    final result = await repository.screenCv(
      jobDescription: 'JD',
      cvText: 'CV',
      cvUrl: 'https://example.com/cv.pdf',
    );

    expect(
      captured.url.toString(),
      'https://cv-ai.example.com/prod/api/v1/cv/screen',
    );
    expect(captured.headers['Authorization'], 'Bearer id-token');
    expect(captured.headers['Content-Type'], 'application/json');
    expect(jsonDecode(captured.body), {
      'job_description': 'JD',
      'cv_text': 'CV',
      'cv_url': 'https://example.com/cv.pdf',
    });
    expect(result.score, 88);
  });

  test('startInterview sends job, cv and custom questions', () async {
    late Map<String, dynamic> payload;
    final client = MockClient((request) async {
      payload = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      return _jsonResponse({'session_id': 'sess_1', 'question': 'Xin chào?'});
    });
    final repository = AwsAiInterviewRepository(
      client: client,
      tokenProvider: () async => 'id-token',
      baseUrl: 'https://cv-ai.example.com/prod/',
    );

    final result = await repository.startInterview(
      jobTitle: 'Phục vụ',
      jobDescription: 'JD',
      cvText: 'CV',
      cvUrl: 'https://example.com/cv.pdf',
      customQuestions: const ['Bạn làm ca tối được không?'],
    );

    expect(result.sessionId, 'sess_1');
    expect(payload['job_title'], 'Phục vụ');
    expect(payload['custom_questions'], ['Bạn làm ca tối được không?']);
  });

  test('respondInterview parses finished report', () async {
    final client = MockClient((request) async {
      return _jsonResponse({
        'question': null,
        'finished': true,
        'report': {
          'total_score': 70,
          'strengths': ['Tốt'],
          'weaknesses': <String>[],
          'recommend_to_employer': true,
          'reason': 'Đạt.',
        },
      });
    });
    final repository = AwsAiInterviewRepository(
      client: client,
      tokenProvider: () async => 'id-token',
      baseUrl: 'https://cv-ai.example.com/prod',
    );

    final result = await repository.respondInterview(
      sessionId: 'sess_1',
      answer: 'Tôi có thể làm ca tối.',
    );

    expect(result.finished, isTrue);
    expect(result.report?.totalScore, 70);
    expect(result.report?.isPassed, isTrue);
  });

  test('throws auth exception when token provider returns null', () async {
    final repository = AwsAiInterviewRepository(
      client: MockClient((_) async => http.Response('{}', 200)),
      tokenProvider: () async => null,
      baseUrl: 'https://cv-ai.example.com/prod',
    );

    await expectLater(
      repository.screenCv(jobDescription: 'JD', cvText: 'CV'),
      throwsA(
        isA<AiInterviewException>().having(
          (error) => error.code,
          'code',
          'AUTH_REQUIRED',
        ),
      ),
    );
  });

  test('maps non-200 response to AiInterviewException', () async {
    final repository = AwsAiInterviewRepository(
      client: MockClient((_) async {
        return _jsonResponse({
          'error': {'code': 'AI_RATE_LIMITED', 'message': 'Busy'},
        }, 429);
      }),
      tokenProvider: () async => 'id-token',
      baseUrl: 'https://cv-ai.example.com/prod',
    );

    await expectLater(
      repository.screenCv(jobDescription: 'JD', cvText: 'CV'),
      throwsA(
        isA<AiInterviewException>().having(
          (error) => error.code,
          'code',
          'AI_RATE_LIMITED',
        ),
      ),
    );
  });

  test('maps timeout to timeout exception', () async {
    final repository = AwsAiInterviewRepository(
      client: MockClient(
        (_) => Future<http.Response>.delayed(
          const Duration(milliseconds: 50),
          () => http.Response('{}', 200),
        ),
      ),
      tokenProvider: () async => 'id-token',
      baseUrl: 'https://cv-ai.example.com/prod',
      screenTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      repository.screenCv(jobDescription: 'JD', cvText: 'CV'),
      throwsA(
        isA<AiInterviewException>().having(
          (error) => error.code,
          'code',
          'TIMEOUT',
        ),
      ),
    );
  });
}

http.Response _jsonResponse(Map<String, dynamic> body, [int statusCode = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
