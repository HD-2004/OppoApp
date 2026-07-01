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
    final json = await _postJson('/api/v1/cv/screen', {
      'job_description': jobDescription,
      'cv_text': cvText,
      'cv_url': cvUrl ?? '',
    }, timeout: screenTimeout);
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
    final json = await _postJson('/api/v1/interview/start', {
      'job_title': jobTitle,
      'job_description': jobDescription,
      'cv_text': cvText,
      'cv_url': cvUrl ?? '',
      'custom_questions': customQuestions,
    }, timeout: startTimeout);
    return InterviewStartResult.fromJson(json);
  }

  @override
  Future<InterviewAnswerResult> respondInterview({
    required String sessionId,
    required String answer,
  }) async {
    final json = await _postJson('/api/v1/interview/respond', {
      'session_id': sessionId,
      'answer': answer,
    }, timeout: respondTimeout);
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
      final code =
          errorMap?['code']?.toString() ?? 'HTTP_${response.statusCode}';
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
    if (statusCode == 401) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (statusCode == 403) {
      return 'Tài khoản này không có quyền dùng phỏng vấn AI.';
    }
    if (statusCode == 429) {
      return 'Dịch vụ AI đang bận. Vui lòng thử lại sau.';
    }
    if (statusCode >= 500) {
      return 'Dịch vụ AI tạm thời gián đoạn. Vui lòng thử lại.';
    }
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
