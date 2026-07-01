# AI Interview Shared Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the Flutter app AI screening/interview flow from local FastAPI calls to the shared website `cv-ai` Lambda, while keeping Phase 1 low cost and low risk.

**Architecture:** Add a small domain/repository layer for the shared AI contract, then update the existing AI screens to use it instead of calling `localhost:8000`. Align the app lifecycle with the website by creating the application after Round 1 pass/review and updating the same application after Round 2 pass.

**Tech Stack:** Flutter, Dart, Riverpod, `package:http`, AWS Amplify Cognito, AWS API Gateway/Lambda, Flutter tests with `http/testing.dart`.

---

## File Structure

- Create `lib/core/config/api_config.dart`
  - Owns API base URL constants used by shared serverless services.
  - Defines `cvAiApiBaseUrl` from `--dart-define=CV_AI_API_URL`.

- Create `lib/features/candidate/domain/ai_interview_models.dart`
  - Pure Dart response models for CV screening and interview.
  - Keeps JSON parsing out of widgets.

- Create `lib/features/candidate/domain/ai_interview_repository.dart`
  - Interface used by presentation code and tests.

- Create `lib/features/candidate/data/aws_ai_interview_repository.dart`
  - AWS/API Gateway implementation.
  - Gets Cognito id token with Amplify.
  - Sends authenticated JSON requests.
  - Maps non-2xx, timeout, and malformed JSON into `AiInterviewException`.

- Create `lib/features/candidate/application/ai_interview_providers.dart`
  - Riverpod provider for the concrete repository.

- Modify `lib/features/candidate/domain/application_repository.dart`
  - Add `updateApplicationStatus`.

- Modify `lib/features/candidate/data/aws_application_repository.dart`
  - Implement `updateApplicationStatus`.
  - Add `buildApplicationStatusPayload` helper for focused tests.

- Modify `lib/features/candidate/presentation/ai_screening_screen.dart`
  - Use `AiInterviewRepository`.
  - Submit application after Round 1 pass/review.
  - Pass `applicationId` to the interview screen.

- Modify `lib/features/candidate/presentation/ai_interview_chat_screen.dart`
  - Use `AiInterviewRepository`.
  - Update existing application after Round 2 pass.

- Create `test/ai_interview_models_test.dart`
- Create `test/aws_ai_interview_repository_test.dart`
- Modify `test/aws_application_repository_test.dart`
- Create `test/ai_interview_flow_cost_guard_test.dart`

---

### Task 1: API Config And Domain Models

**Files:**
- Create: `lib/core/config/api_config.dart`
- Create: `lib/features/candidate/domain/ai_interview_models.dart`
- Test: `test/ai_interview_models_test.dart`

- [ ] **Step 1: Write model tests**

Create `test/ai_interview_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/ai_interview_models.dart';

void main() {
  test('parses CV screening response from shared cv-ai contract', () {
    final result = CvScreeningResult.fromJson({
      'score': 85,
      'result': 'pass',
      'strengths': ['Giao tiếp tốt'],
      'weaknesses': ['Cần học quy trình quán'],
      'reason': 'Phù hợp với vị trí phục vụ.',
    });

    expect(result.score, 85);
    expect(result.result, 'pass');
    expect(result.isFailed, isFalse);
    expect(result.canContinueToInterview, isTrue);
    expect(result.strengths, ['Giao tiếp tốt']);
    expect(result.weaknesses, ['Cần học quy trình quán']);
    expect(result.reason, 'Phù hợp với vị trí phục vụ.');
  });

  test('treats review screening result as eligible for application creation', () {
    final result = CvScreeningResult.fromJson({
      'score': 61,
      'result': 'review',
      'strengths': <String>[],
      'weaknesses': <String>[],
      'reason': 'Cần xem xét thêm.',
    });

    expect(result.canContinueToInterview, isTrue);
  });

  test('parses unfinished and finished interview responses', () {
    final next = InterviewAnswerResult.fromJson({
      'question': 'Bạn xử lý khách phàn nàn như thế nào?',
      'finished': false,
      'report': null,
    });
    expect(next.finished, isFalse);
    expect(next.question, 'Bạn xử lý khách phàn nàn như thế nào?');
    expect(next.report, isNull);

    final done = InterviewAnswerResult.fromJson({
      'question': null,
      'finished': true,
      'report': {
        'total_score': 72,
        'past_experience_score': 70,
        'situation_handling_score': 74,
        'operations_score': 73,
        'custom_questions_score': 71,
        'strengths': ['Thái độ tốt'],
        'weaknesses': ['Cần quen ca cao điểm'],
        'recommend_to_employer': true,
        'reason': 'Ứng viên phù hợp.',
      },
    });

    expect(done.finished, isTrue);
    expect(done.report?.totalScore, 72);
    expect(done.report?.isPassed, isTrue);
    expect(done.report?.pastExperienceScore, 70);
    expect(done.report?.toJson()['total_score'], 72);
  });

  test('uses website pass threshold of 60 for interview reports', () {
    final report = InterviewReport.fromJson({
      'total_score': 60,
      'strengths': <String>[],
      'weaknesses': <String>[],
      'recommend_to_employer': false,
      'reason': 'Đạt ngưỡng tối thiểu.',
    });

    expect(report.isPassed, isTrue);
  });
}
```

- [ ] **Step 2: Run model tests and verify RED**

Run:

```powershell
flutter test test/ai_interview_models_test.dart
```

Expected: FAIL because `ai_interview_models.dart` does not exist.

- [ ] **Step 3: Add API config**

Create `lib/core/config/api_config.dart`:

```dart
const cvAiApiBaseUrl = String.fromEnvironment(
  'CV_AI_API_URL',
  defaultValue: 'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod',
);
```

- [ ] **Step 4: Add AI interview models**

Create `lib/features/candidate/domain/ai_interview_models.dart`:

```dart
class CvScreeningResult {
  const CvScreeningResult({
    required this.score,
    required this.result,
    required this.strengths,
    required this.weaknesses,
    required this.reason,
  });

  factory CvScreeningResult.fromJson(Map<String, dynamic> json) {
    return CvScreeningResult(
      score: _int(json['score']).clamp(0, 100),
      result: _string(json['result']).isEmpty ? 'review' : _string(json['result']),
      strengths: _stringList(json['strengths']),
      weaknesses: _stringList(json['weaknesses']),
      reason: _string(json['reason']),
    );
  }

  final int score;
  final String result;
  final List<String> strengths;
  final List<String> weaknesses;
  final String reason;

  bool get isFailed => result.toLowerCase().trim() == 'fail';
  bool get canContinueToInterview => !isFailed;

  Map<String, dynamic> toApplicationExtraFields() {
    return {
      'aiScreeningScore': score,
      'aiScreeningResult': result,
      'aiScreeningReason': reason,
      'aiScreeningStrengths': strengths,
      'aiScreeningWeaknesses': weaknesses,
    };
  }
}

class InterviewStartResult {
  const InterviewStartResult({required this.sessionId, required this.question});

  factory InterviewStartResult.fromJson(Map<String, dynamic> json) {
    return InterviewStartResult(
      sessionId: _string(json['session_id']),
      question: _string(json['question']),
    );
  }

  final String sessionId;
  final String question;
}

class InterviewAnswerResult {
  const InterviewAnswerResult({
    required this.question,
    required this.finished,
    required this.report,
  });

  factory InterviewAnswerResult.fromJson(Map<String, dynamic> json) {
    final rawReport = json['report'];
    return InterviewAnswerResult(
      question: _nullableString(json['question']),
      finished: json['finished'] == true,
      report: rawReport is Map
          ? InterviewReport.fromJson(Map<String, dynamic>.from(rawReport))
          : null,
    );
  }

  final String? question;
  final bool finished;
  final InterviewReport? report;
}

class InterviewReport {
  const InterviewReport({
    required this.totalScore,
    required this.strengths,
    required this.weaknesses,
    required this.recommendToEmployer,
    required this.reason,
    this.pastExperienceScore,
    this.situationHandlingScore,
    this.operationsScore,
    this.customQuestionsScore,
  });

  factory InterviewReport.fromJson(Map<String, dynamic> json) {
    return InterviewReport(
      totalScore: _int(json['total_score']).clamp(0, 100),
      pastExperienceScore: _nullableInt(json['past_experience_score']),
      situationHandlingScore: _nullableInt(json['situation_handling_score']),
      operationsScore: _nullableInt(json['operations_score']),
      customQuestionsScore: _nullableInt(json['custom_questions_score']),
      strengths: _stringList(json['strengths']),
      weaknesses: _stringList(json['weaknesses']),
      recommendToEmployer: json['recommend_to_employer'] == true,
      reason: _string(json['reason']),
    );
  }

  final int totalScore;
  final int? pastExperienceScore;
  final int? situationHandlingScore;
  final int? operationsScore;
  final int? customQuestionsScore;
  final List<String> strengths;
  final List<String> weaknesses;
  final bool recommendToEmployer;
  final String reason;

  bool get isPassed => recommendToEmployer || totalScore >= 60;

  Map<String, dynamic> toJson() {
    return {
      'total_score': totalScore,
      if (pastExperienceScore != null) 'past_experience_score': pastExperienceScore,
      if (situationHandlingScore != null) 'situation_handling_score': situationHandlingScore,
      if (operationsScore != null) 'operations_score': operationsScore,
      if (customQuestionsScore != null) 'custom_questions_score': customQuestionsScore,
      'strengths': strengths,
      'weaknesses': weaknesses,
      'recommend_to_employer': recommendToEmployer,
      'reason': reason,
    };
  }
}

String _string(dynamic value) => value?.toString().trim() ?? '';

String? _nullableString(dynamic value) {
  final text = _string(value);
  return text.isEmpty ? null : text;
}

int _int(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(_string(value)) ?? 0;
}

int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(_string(value));
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}
```

- [ ] **Step 5: Run model tests and verify GREEN**

Run:

```powershell
flutter test test/ai_interview_models_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 1**

Run:

```powershell
git add lib/core/config/api_config.dart lib/features/candidate/domain/ai_interview_models.dart test/ai_interview_models_test.dart
git commit -m "feat: add ai interview contract models"
```

---

### Task 2: AI Interview Repository

**Files:**
- Create: `lib/features/candidate/domain/ai_interview_repository.dart`
- Create: `lib/features/candidate/data/aws_ai_interview_repository.dart`
- Create: `lib/features/candidate/application/ai_interview_providers.dart`
- Test: `test/aws_ai_interview_repository_test.dart`

- [ ] **Step 1: Write repository tests**

Create `test/aws_ai_interview_repository_test.dart`:

```dart
import 'dart:async';
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
      return http.Response(
        jsonEncode({
          'score': 88,
          'result': 'pass',
          'strengths': ['Phù hợp'],
          'weaknesses': <String>[],
          'reason': 'Đạt vòng 1.',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
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

    expect(captured.url.toString(), 'https://cv-ai.example.com/prod/api/v1/cv/screen');
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
      return http.Response(
        jsonEncode({'session_id': 'sess_1', 'question': 'Xin chào?'}),
        200,
      );
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
      return http.Response(
        jsonEncode({
          'question': null,
          'finished': true,
          'report': {
            'total_score': 70,
            'strengths': ['Tốt'],
            'weaknesses': <String>[],
            'recommend_to_employer': true,
            'reason': 'Đạt.',
          },
        }),
        200,
      );
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
        return http.Response(
          jsonEncode({
            'error': {'code': 'AI_RATE_LIMITED', 'message': 'Busy'},
          }),
          429,
        );
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
      client: MockClient((_) => Future<http.Response>.delayed(
        const Duration(milliseconds: 50),
        () => http.Response('{}', 200),
      )),
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
```

- [ ] **Step 2: Run repository tests and verify RED**

Run:

```powershell
flutter test test/aws_ai_interview_repository_test.dart
```

Expected: FAIL because repository files do not exist.

- [ ] **Step 3: Add repository interface**

Create `lib/features/candidate/domain/ai_interview_repository.dart`:

```dart
import 'ai_interview_models.dart';

abstract class AiInterviewRepository {
  Future<CvScreeningResult> screenCv({
    required String jobDescription,
    required String cvText,
    String? cvUrl,
  });

  Future<InterviewStartResult> startInterview({
    required String jobTitle,
    required String jobDescription,
    required String cvText,
    String? cvUrl,
    List<String> customQuestions = const [],
  });

  Future<InterviewAnswerResult> respondInterview({
    required String sessionId,
    required String answer,
  });
}

class AiInterviewException implements Exception {
  const AiInterviewException(this.message, {this.code = 'AI_INTERVIEW_ERROR'});

  final String message;
  final String code;

  @override
  String toString() => message;
}
```

- [ ] **Step 4: Add AWS repository implementation**

Create `lib/features/candidate/data/aws_ai_interview_repository.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../domain/ai_interview_models.dart';
import '../domain/ai_interview_repository.dart';

class AwsAiInterviewRepository implements AiInterviewRepository {
  AwsAiInterviewRepository({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    String baseUrl = cvAiApiBaseUrl,
    this.screenTimeout = const Duration(seconds: 30),
    this.startTimeout = const Duration(seconds: 30),
    this.respondTimeout = const Duration(seconds: 35),
  }) : _client = client ?? http.Client(),
       _tokenProvider = tokenProvider ?? _getCognitoIdToken,
       _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final Future<String?> Function() _tokenProvider;
  final String _baseUrl;
  final Duration screenTimeout;
  final Duration startTimeout;
  final Duration respondTimeout;

  @override
  Future<CvScreeningResult> screenCv({
    required String jobDescription,
    required String cvText,
    String? cvUrl,
  }) async {
    final json = await _postJson(
      '/api/v1/cv/screen',
      {
        'job_description': jobDescription,
        'cv_text': cvText,
        'cv_url': cvUrl ?? '',
      },
      timeout: screenTimeout,
    );
    return CvScreeningResult.fromJson(json);
  }

  @override
  Future<InterviewStartResult> startInterview({
    required String jobTitle,
    required String jobDescription,
    required String cvText,
    String? cvUrl,
    List<String> customQuestions = const [],
  }) async {
    final json = await _postJson(
      '/api/v1/interview/start',
      {
        'job_title': jobTitle,
        'job_description': jobDescription,
        'cv_text': cvText,
        'cv_url': cvUrl ?? '',
        'custom_questions': customQuestions,
      },
      timeout: startTimeout,
    );
    return InterviewStartResult.fromJson(json);
  }

  @override
  Future<InterviewAnswerResult> respondInterview({
    required String sessionId,
    required String answer,
  }) async {
    final json = await _postJson(
      '/api/v1/interview/respond',
      {'session_id': sessionId, 'answer': answer},
      timeout: respondTimeout,
    );
    return InterviewAnswerResult.fromJson(json);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    required Duration timeout,
  }) async {
    final token = await _tokenProvider();
    if (token == null || token.trim().isEmpty) {
      throw const AiInterviewException(
        'Vui lòng đăng nhập lại để sử dụng phỏng vấn AI.',
        code: 'AUTH_REQUIRED',
      );
    }

    final response = await _client
        .post(
          Uri.parse('$_baseUrl$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(
          timeout,
          onTimeout: () {
            throw const AiInterviewException(
              'Dịch vụ AI phản hồi quá chậm. Vui lòng thử lại.',
              code: 'TIMEOUT',
            );
          },
        );

    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final errorMap = error is Map ? Map<String, dynamic>.from(error) : null;
      final code = errorMap?['code']?.toString() ?? 'HTTP_${response.statusCode}';
      final message =
          errorMap?['message']?.toString() ??
          decoded['message']?.toString() ??
          _defaultMessageForStatus(response.statusCode);
      throw AiInterviewException(message, code: code);
    }
    return decoded;
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      final body = utf8.decode(response.bodyBytes);
      if (body.trim().isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException catch (error) {
      throw AiInterviewException(
        'Dữ liệu phản hồi từ AI không hợp lệ: $error',
        code: 'INVALID_JSON',
      );
    }
    throw const AiInterviewException(
      'Dữ liệu phản hồi từ AI không hợp lệ.',
      code: 'INVALID_JSON',
    );
  }

  String _defaultMessageForStatus(int statusCode) {
    if (statusCode == 401) return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    if (statusCode == 403) return 'Tài khoản này không có quyền dùng phỏng vấn AI.';
    if (statusCode == 429) return 'Dịch vụ AI đang bận. Vui lòng thử lại sau.';
    if (statusCode >= 500) return 'Dịch vụ AI tạm thời gián đoạn. Vui lòng thử lại.';
    return 'Không thể xử lý yêu cầu AI. Vui lòng thử lại.';
  }

  static Future<String?> _getCognitoIdToken() async {
    try {
      final plugin = Amplify.Auth.getPlugin(AmplifyAuthCognito.pluginKey);
      final session = await plugin.fetchAuthSession();
      final tokens = session.userPoolTokensResult.valueOrNull;
      return tokens?.idToken.raw;
    } catch (error) {
      safePrint('Error getting AI interview auth token: $error');
      return null;
    }
  }
}
```

- [ ] **Step 5: Add Riverpod provider**

Create `lib/features/candidate/application/ai_interview_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/aws_ai_interview_repository.dart';
import '../domain/ai_interview_repository.dart';

final aiInterviewRepositoryProvider = Provider<AiInterviewRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AwsAiInterviewRepository(client: client);
});
```

- [ ] **Step 6: Run repository tests and verify GREEN**

Run:

```powershell
flutter test test/aws_ai_interview_repository_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit Task 2**

Run:

```powershell
git add lib/features/candidate/domain/ai_interview_repository.dart lib/features/candidate/data/aws_ai_interview_repository.dart lib/features/candidate/application/ai_interview_providers.dart test/aws_ai_interview_repository_test.dart
git commit -m "feat: add shared ai interview repository"
```

---

### Task 3: Application Status Update Contract

**Files:**
- Modify: `lib/features/candidate/domain/application_repository.dart`
- Modify: `lib/features/candidate/data/aws_application_repository.dart`
- Modify: `test/aws_application_repository_test.dart`

- [ ] **Step 1: Add payload tests**

Append these tests to `test/aws_application_repository_test.dart`:

```dart
  test('builds application status payload with AI interview fields', () {
    final report = {
      'total_score': 72,
      'strengths': ['Thái độ tốt'],
      'weaknesses': ['Cần quen ca cao điểm'],
      'recommend_to_employer': true,
      'reason': 'Ứng viên phù hợp.',
    };

    expect(
      buildApplicationStatusPayload(
        status: 'approved',
        extraFields: {
          'aiInterviewScore': 72,
          'aiInterviewReport': report,
        },
      ),
      {
        'status': 'approved',
        'aiInterviewScore': 72,
        'aiInterviewReport': report,
      },
    );
  });
```

- [ ] **Step 2: Run application repository tests and verify RED**

Run:

```powershell
flutter test test/aws_application_repository_test.dart
```

Expected: FAIL because `buildApplicationStatusPayload` does not exist.

- [ ] **Step 3: Add interface method**

Modify `lib/features/candidate/domain/application_repository.dart` by adding this method to `abstract class ApplicationRepository` after `submitApplication`:

```dart
  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    Map<String, dynamic> extraFields = const {},
  });
```

- [ ] **Step 4: Add payload helper and implementation**

In `lib/features/candidate/data/aws_application_repository.dart`, add this helper near the existing payload helpers:

```dart
Map<String, dynamic> buildApplicationStatusPayload({
  required String status,
  Map<String, dynamic> extraFields = const {},
}) {
  return {'status': status, ...extraFields};
}
```

Add this method inside `class AwsApplicationRepository implements ApplicationRepository`, after `submitApplication`:

```dart
  @override
  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    Map<String, dynamic> extraFields = const {},
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Vui lòng đăng nhập để cập nhật hồ sơ ứng tuyển.');
    }

    final response = await http.put(
      Uri.parse(
        '$_applicationsBaseUrl/applications/'
        '${Uri.encodeComponent(applicationId)}/status',
      ),
      headers: _buildHeaders(token),
      body: jsonEncode(
        buildApplicationStatusPayload(status: status, extraFields: extraFields),
      ),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final errorMsg =
          body['error'] ?? body['message'] ?? 'Không thể cập nhật hồ sơ ứng tuyển';
      throw Exception(errorMsg);
    }
  }
```

- [ ] **Step 5: Run application repository tests and verify GREEN**

Run:

```powershell
flutter test test/aws_application_repository_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit Task 3**

Run:

```powershell
git add lib/features/candidate/domain/application_repository.dart lib/features/candidate/data/aws_application_repository.dart test/aws_application_repository_test.dart
git commit -m "feat: support application ai interview updates"
```

---

### Task 4: Migrate AI Screening Screen

**Files:**
- Modify: `lib/features/candidate/presentation/ai_screening_screen.dart`
- Test: `test/ai_interview_flow_cost_guard_test.dart`

- [ ] **Step 1: Write cost guard tests**

Create `test/ai_interview_flow_cost_guard_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/ai_interview_models.dart';

bool shouldCreateApplicationAfterScreening(CvScreeningResult result) {
  return result.canContinueToInterview;
}

bool shouldApproveApplicationAfterInterview(InterviewReport? report) {
  return report?.isPassed == true;
}

void main() {
  test('Round 1 fail does not create application', () {
    final result = CvScreeningResult.fromJson({
      'score': 0,
      'result': 'fail',
      'strengths': <String>[],
      'weaknesses': ['Không phải CV'],
      'reason': 'Tài liệu không hợp lệ.',
    });

    expect(shouldCreateApplicationAfterScreening(result), isFalse);
  });

  test('Round 1 pass and review create application', () {
    final pass = CvScreeningResult.fromJson({
      'score': 80,
      'result': 'pass',
      'strengths': <String>[],
      'weaknesses': <String>[],
      'reason': 'Đạt.',
    });
    final review = CvScreeningResult.fromJson({
      'score': 60,
      'result': 'review',
      'strengths': <String>[],
      'weaknesses': <String>[],
      'reason': 'Cần xem xét.',
    });

    expect(shouldCreateApplicationAfterScreening(pass), isTrue);
    expect(shouldCreateApplicationAfterScreening(review), isTrue);
  });

  test('Round 2 only approves when website threshold passes', () {
    final failed = InterviewReport.fromJson({
      'total_score': 59,
      'strengths': <String>[],
      'weaknesses': <String>[],
      'recommend_to_employer': false,
      'reason': 'Chưa đạt.',
    });
    final passed = InterviewReport.fromJson({
      'total_score': 60,
      'strengths': <String>[],
      'weaknesses': <String>[],
      'recommend_to_employer': false,
      'reason': 'Đạt ngưỡng.',
    });

    expect(shouldApproveApplicationAfterInterview(failed), isFalse);
    expect(shouldApproveApplicationAfterInterview(passed), isTrue);
  });
}
```

- [ ] **Step 2: Run cost guard tests and verify GREEN**

Run:

```powershell
flutter test test/ai_interview_flow_cost_guard_test.dart
```

Expected: PASS because Task 1 models already define the decision behavior.

- [ ] **Step 3: Replace direct `http` usage in screening screen**

In `lib/features/candidate/presentation/ai_screening_screen.dart`:

Remove:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
```

Add:

```dart
import '../application/ai_interview_providers.dart';
import '../domain/ai_interview_models.dart';
import '../domain/application_repository.dart';
import '../data/aws_application_repository.dart';
```

Add state fields inside `_AIScreeningScreenState`:

```dart
  String? _applicationId;
```

Replace the `http.post` block in `_runCVScreening` with:

```dart
      final screeningResult = await ref
          .read(aiInterviewRepositoryProvider)
          .screenCv(
            jobDescription: jdText,
            cvText: cvText,
            cvUrl: widget.cvUrl,
          );

      setState(() {
        _score = screeningResult.score;
        _result = screeningResult.result;
        _strengths = screeningResult.strengths;
        _weaknesses = screeningResult.weaknesses;
        _reason = screeningResult.reason;
        _isLoading = false;

        _progressAnimation = Tween<double>(
          begin: 0,
          end: _score / 100.0,
        ).animate(
          CurvedAnimation(
            parent: _progressController,
            curve: Curves.easeOutCubic,
          ),
        );
        _progressController.forward();
      });

      if (screeningResult.canContinueToInterview) {
        await _submitRoundOneApplication(screeningResult);
      }
```

Add helper method inside `_AIScreeningScreenState`:

```dart
  Future<void> _submitRoundOneApplication(CvScreeningResult result) async {
    if (_applicationId != null) return;

    final user = ref.read(authControllerProvider).asData?.value.user;
    if (user == null) {
      throw Exception('Vui lòng đăng nhập để ứng tuyển.');
    }

    final repository = ref.read(applicationRepositoryProvider);
    final response = await repository.submitApplication(
      jobId: widget.job.idJob,
      cvUrl: widget.cvUrl,
      cvFilename: widget.cvFileName,
      notification: ApplicationNotificationDetails(
        employerId: widget.job.employerId,
        candidateId: user.userId,
        candidateName: user.fullName,
        jobTitle: widget.job.title,
        companyName: widget.job.companyName ?? widget.job.employerName,
        isQuickJob: widget.job.isQuickJob,
      ),
      extraFields: result.toApplicationExtraFields(),
    );

    final application = response['application'];
    final id = response['applicationId'] ??
        (application is Map ? application['applicationId'] : null);
    if (id != null && mounted) {
      setState(() => _applicationId = id.toString());
    }
  }
```

This helper requires `submitApplication` to return `Future<Map<String, dynamic>>`, so Task 5 will adjust the repository signature and implementation before this screen compiles. Keep the screen edit in the same implementation checkpoint as Task 5 if executing manually.

- [ ] **Step 4: Pass application id into interview screen**

In the `AIInterviewChatScreen` constructor call inside `ai_screening_screen.dart`, add:

```dart
                      applicationId: _applicationId,
```

Also disable the start interview button until `_applicationId != null` when `_result` is not `fail`:

```dart
              onPressed: _applicationId == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AIInterviewChatScreen(
                            job: widget.job,
                            cvFileName: widget.cvFileName,
                            cvUrl: widget.cvUrl,
                            cvS3Key: widget.cvS3Key,
                            applicationId: _applicationId,
                            aiScreeningScore: _score,
                            aiScreeningResult: _result,
                            aiScreeningReason: _reason,
                          ),
                        ),
                      );
                    },
```

- [ ] **Step 5: Update error message**

In `_runCVScreening` catch block, replace the localhost-specific message with:

```dart
        _errorMessage =
            'Không thể kết nối đến dịch vụ phỏng vấn AI. Vui lòng kiểm tra kết nối mạng và thử lại.\nChi tiết: $e';
```

- [ ] **Step 6: Defer compile verification until Task 5**

Run after Task 5 because `ApplicationRepository.submitApplication` still returns `Future<void>` before the next task:

```powershell
flutter analyze
```

Expected after Task 5: no compile errors from `AIScreeningScreen`.

---

### Task 5: Return Application Id From Submit

**Files:**
- Modify: `lib/features/candidate/domain/application_repository.dart`
- Modify: `lib/features/candidate/data/aws_application_repository.dart`

- [ ] **Step 1: Change application repository interface**

In `lib/features/candidate/domain/application_repository.dart`, change `submitApplication` from:

```dart
  Future<void> submitApplication({
```

to:

```dart
  Future<Map<String, dynamic>> submitApplication({
```

- [ ] **Step 2: Change AWS repository method signature and return body**

In `lib/features/candidate/data/aws_application_repository.dart`, change:

```dart
  Future<void> submitApplication({
```

to:

```dart
  Future<Map<String, dynamic>> submitApplication({
```

After the successful response check and notification call, return the decoded response body:

```dart
    await _sendEmployerApplicationNotification(
      jobId: jobId,
      details: notification,
    );

    final body = jsonDecode(response.body);
    return body is Map<String, dynamic>
        ? body
        : Map<String, dynamic>.from(body as Map);
```

If `body` is already decoded earlier in the error branch only, introduce a success decode variable before notification:

```dart
    final successBody = jsonDecode(response.body);

    await _sendEmployerApplicationNotification(
      jobId: jobId,
      details: notification,
    );

    return successBody is Map<String, dynamic>
        ? successBody
        : Map<String, dynamic>.from(successBody as Map);
```

- [ ] **Step 3: Confirm callers that ignore the return still compile**

Run:

```powershell
rg -n "submitApplication\\(" lib test
```

Expected: existing callers may ignore the returned map; Dart allows ignoring a `Future<Map<String, dynamic>>` where the awaited value is unused.

- [ ] **Step 4: Run focused tests and analyze**

Run:

```powershell
flutter test test/aws_application_repository_test.dart test/ai_interview_flow_cost_guard_test.dart
flutter analyze
```

Expected: tests PASS and analyze has no errors from the changed signature.

- [ ] **Step 5: Commit Tasks 4 and 5 together**

Run:

```powershell
git add lib/features/candidate/presentation/ai_screening_screen.dart lib/features/candidate/domain/application_repository.dart lib/features/candidate/data/aws_application_repository.dart test/ai_interview_flow_cost_guard_test.dart
git commit -m "feat: create applications after ai screening"
```

---

### Task 6: Migrate AI Interview Chat Screen

**Files:**
- Modify: `lib/features/candidate/presentation/ai_interview_chat_screen.dart`

- [ ] **Step 1: Update constructor**

In `AIInterviewChatScreen`, add a nullable `applicationId` field:

```dart
  final String? applicationId;
```

Add it to the constructor:

```dart
    this.applicationId,
```

- [ ] **Step 2: Replace imports**

Remove:

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart';
```

Add:

```dart
import '../application/ai_interview_providers.dart';
import '../domain/ai_interview_models.dart';
```

Keep application repository imports because the screen updates the existing application.

- [ ] **Step 3: Replace start interview HTTP call**

In `_startInterviewSession`, replace the `http.post` block with:

```dart
      final result = await ref
          .read(aiInterviewRepositoryProvider)
          .startInterview(
            jobTitle: widget.job.title,
            jobDescription: jdText,
            cvText: cvText,
            cvUrl: widget.cvUrl,
            customQuestions: widget.job.customQuestions,
          );

      setState(() {
        _sessionId = result.sessionId;
        _isLoading = false;
        _messages.add(ChatMessage(
          text: result.question.isNotEmpty
              ? result.question
              : 'Chào bạn, hãy bắt đầu buổi phỏng vấn.',
          isMe: false,
          time: DateTime.now(),
        ));
      });
      _scrollToBottom();
```

- [ ] **Step 4: Replace respond interview HTTP call**

In `_handleSendAnswer`, replace the `http.post` block with:

```dart
      final data = await ref
          .read(aiInterviewRepositoryProvider)
          .respondInterview(sessionId: _sessionId!, answer: text);

      setState(() {
        _isSending = false;
        _finished = data.finished;

        if (_finished) {
          _report = data.report?.toJson();
          _messages.add(ChatMessage(
            text:
                'Cảm ơn bạn đã tham gia buổi phỏng vấn. Hệ thống đang tổng hợp kết quả của bạn...',
            isMe: false,
            time: DateTime.now(),
          ));
          _showReportDialog();
          _submitDeferredApplication(data.report);
        } else {
          _messages.add(ChatMessage(
            text: data.question ?? '',
            isMe: false,
            time: DateTime.now(),
          ));
        }
      });
      _scrollToBottom();
```

- [ ] **Step 5: Update deferred application submission**

Replace `_submitDeferredApplication()` with:

```dart
  Future<void> _submitDeferredApplication(InterviewReport? report) async {
    if (report == null || !report.isPassed) {
      return;
    }

    final applicationId = widget.applicationId;
    if (applicationId == null || applicationId.trim().isEmpty) {
      safePrint('AI interview finished without applicationId; skipping update');
      return;
    }

    try {
      final extraFields = {
        'aiScreeningScore': widget.aiScreeningScore,
        'aiScreeningResult': widget.aiScreeningResult,
        'aiScreeningReason': widget.aiScreeningReason,
        'aiInterviewScore': report.totalScore,
        'aiInterviewReport': report.toJson(),
      };

      await ref.read(applicationRepositoryProvider).updateApplicationStatus(
            applicationId: applicationId,
            status: 'approved',
            extraFields: extraFields,
          );

      safePrint('AI interview application updated successfully');
    } catch (error) {
      safePrint('Failed to update application after AI interview: $error');
    }
  }
```

- [ ] **Step 6: Remove old submit-after-interview branch**

Delete the old logic in `_submitDeferredApplication` that calls:

```dart
repository.submitApplication(...)
```

Expected: Round 2 updates the application created after Round 1 instead of creating a duplicate.

- [ ] **Step 7: Run analyze**

Run:

```powershell
flutter analyze
```

Expected: no errors from `AIInterviewChatScreen`.

- [ ] **Step 8: Commit Task 6**

Run:

```powershell
git add lib/features/candidate/presentation/ai_interview_chat_screen.dart
git commit -m "feat: update applications after ai interview"
```

---

### Task 7: Regression And Backend Contract Verification

**Files:**
- No source file changes expected unless verification exposes a bug.

- [ ] **Step 1: Run shared backend contract tests**

Run:

```powershell
Set-Location C:\OpPoReview\amplify\backend\cv-ai
python -m unittest -v
Set-Location C:\OppoApp
```

Expected: backend contract tests PASS. If they fail because of local Python dependency setup, record the exact missing dependency and run app-side tests anyway.

- [ ] **Step 2: Run app tests for migrated feature**

Run:

```powershell
flutter test test/ai_interview_models_test.dart test/aws_ai_interview_repository_test.dart test/aws_application_repository_test.dart test/ai_interview_flow_cost_guard_test.dart
```

Expected: all listed tests PASS.

- [ ] **Step 3: Run full Flutter tests**

Run:

```powershell
flutter test
```

Expected: all tests PASS. If unrelated pre-existing tests fail, capture the failing test names and confirm whether the failure touches AI migration files.

- [ ] **Step 4: Run analyze**

Run:

```powershell
flutter analyze
```

Expected: no new analysis errors from AI migration files.

- [ ] **Step 5: Verify no local AI endpoint remains**

Run:

```powershell
rg -n "localhost:8000|127\\.0\\.0\\.1:8000" lib test
```

Expected: no output from `lib/features/candidate/presentation/ai_screening_screen.dart` or `lib/features/candidate/presentation/ai_interview_chat_screen.dart`.

- [ ] **Step 6: Verify Phase 1 does not call deferred endpoints**

Run:

```powershell
rg -n "interview/media|audio-upload-url|upload-audio" lib test
```

Expected: no output in app source or tests for Phase 1.

- [ ] **Step 7: Commit final verification fixes if any**

If verification required fixes, commit only those fixes:

```powershell
git add <fixed-files>
git commit -m "fix: stabilize ai interview migration"
```

If no fixes were needed, do not create an empty commit.

---

### Task 8: Manual Smoke Test Handoff

**Files:**
- No source file changes.

- [ ] **Step 1: Run app with shared cv-ai URL**

Run:

```powershell
flutter run --dart-define=CV_AI_API_URL=https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod
```

Expected: app launches and uses the shared AI endpoint.

- [ ] **Step 2: Smoke test Round 1 pass/review**

Use a test candidate account and one job where `isAiScreeningEnabled = true`.

Expected:
- Candidate selects CV.
- Screening returns `pass` or `review`.
- Application is created once.
- Start interview button is enabled after `applicationId` is available.

- [ ] **Step 3: Smoke test Round 1 fail**

Use a non-CV document or test payload that the AI service marks as `fail`.

Expected:
- App displays fail.
- App does not create an application.
- Employer does not receive a new application.

- [ ] **Step 4: Smoke test Round 2 pass**

Complete the interview with serious answers.

Expected:
- App shows report.
- Existing application updates to `approved`.
- Application contains `aiInterviewScore` and `aiInterviewReport`.
- Website can see the same application/report.

- [ ] **Step 5: Smoke test AI service outage behavior**

Temporarily run the app with an invalid `CV_AI_API_URL`:

```powershell
flutter run --dart-define=CV_AI_API_URL=https://invalid.example.com
```

Expected:
- App shows a retry-safe error.
- App does not create fake successful screening results.
- App does not create an application.

---

## Self-Review Notes

- Spec coverage:
  - Shared `cv-ai` endpoint: Tasks 1, 2, 7, 8.
  - Authenticated AI calls: Task 2.
  - Round 1 creates application: Tasks 4, 5.
  - Round 2 updates application: Tasks 3, 6.
  - Cost guards and no mock pass: Tasks 4, 7, 8.
  - Deferred media/audio endpoints excluded: Task 7.
- Completion scan:
  - This plan has concrete implementation steps, commands, and expected outcomes.
- Type consistency:
  - `CvScreeningResult`, `InterviewStartResult`, `InterviewAnswerResult`, and `InterviewReport` are introduced in Task 1 and used consistently later.
  - `AiInterviewRepository` method names match Task 2 implementation and Task 4/6 UI usage.
  - `ApplicationRepository.updateApplicationStatus` is introduced in Task 3 and used in Task 6.
