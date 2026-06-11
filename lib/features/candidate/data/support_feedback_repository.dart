import 'dart:convert';
import 'dart:typed_data';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

import '../../auth/domain/auth_user_profile.dart';

class SupportAttachment {
  const SupportAttachment({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;

  String toDataUrl() => 'data:$mimeType;base64,${base64Encode(bytes)}';
}

class SupportFeedbackException implements Exception {
  const SupportFeedbackException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupportFeedbackRepository {
  SupportFeedbackRepository({
    http.Client? client,
    String? apiBaseUrl,
    Future<String?> Function()? tokenProvider,
  }) : _client = client ?? http.Client(),
       _apiBaseUrl = apiBaseUrl ?? _defaultApiBaseUrl,
       _tokenProvider = tokenProvider ?? _getAuthToken;

  static const _defaultApiBaseUrl =
      'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod';

  final http.Client _client;
  final String _apiBaseUrl;
  final Future<String?> Function() _tokenProvider;

  static Future<String?> _getAuthToken() async {
    try {
      final cognitoPlugin = Amplify.Auth.getPlugin(
        AmplifyAuthCognito.pluginKey,
      );
      final session = await cognitoPlugin.fetchAuthSession();
      return session.userPoolTokensResult.valueOrNull?.idToken.raw;
    } catch (error) {
      safePrint('Error getting support feedback auth token: $error');
      return null;
    }
  }

  Future<void> submit({
    required String category,
    required String comment,
    required AuthUserProfile user,
    List<SupportAttachment> attachments = const [],
  }) async {
    final token = await _tokenProvider();
    final response = await _client.post(
      Uri.parse('$_apiBaseUrl/feedback'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'category': category,
        'comment': comment.trim(),
        'userId': user.userId,
        'userName': user.fullName.trim().isNotEmpty
            ? user.fullName.trim()
            : user.username,
        'userEmail': user.email,
        'userRole': user.role?.name ?? 'candidate',
        if (attachments.isNotEmpty)
          'imageUrls': attachments.map((item) => item.toDataUrl()).toList(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SupportFeedbackException(
        _readErrorMessage(response.body) ??
            'Không thể gửi yêu cầu hỗ trợ (${response.statusCode}).',
      );
    }

    final decoded = _decodeJson(response.body);
    if (decoded is Map<String, dynamic> && decoded['success'] == false) {
      throw SupportFeedbackException(
        decoded['message']?.toString() ?? 'Không thể gửi yêu cầu hỗ trợ.',
      );
    }
  }

  static String? _readErrorMessage(String body) {
    final decoded = _decodeJson(body);
    if (decoded is! Map<String, dynamic>) {
      return body.trim().isEmpty ? null : body.trim();
    }
    return decoded['message']?.toString() ??
        decoded['error']?.toString() ??
        decoded['errorMsg']?.toString();
  }

  static dynamic _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }
}
