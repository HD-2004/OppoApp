import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class EkycRepository {
  static const _apiBaseUrl =
      'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod';

  Future<String?> _getAuthToken() async {
    try {
      final cognitoPlugin = Amplify.Auth.getPlugin(
        AmplifyAuthCognito.pluginKey,
      );
      final session = await cognitoPlugin.fetchAuthSession();
      final tokens = session.userPoolTokensResult.valueOrNull;
      return tokens?.idToken.raw;
    } catch (e) {
      safePrint('Error getting auth token: $e');
      return null;
    }
  }

  Map<String, String> _buildHeaders(String? token) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.trim().isNotEmpty)
        'Authorization': 'Bearer ${token.trim()}',
    };
  }

  Future<Map<String, dynamic>> createVerificationSession({
    required String callbackUrl,
  }) async {
    final token = await _getAuthToken();
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/ekyc/session'),
      headers: _buildHeaders(token),
      body: jsonEncode({'callbackUrl': callbackUrl}),
    );

    final body = _decodeBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw Exception(
      body['errorMsg'] ??
          body['message'] ??
          'Tạo phiên xác minh thất bại (${response.statusCode})',
    );
  }

  Future<Map<String, dynamic>> getKycStatus(String userId) async {
    final token = await _getAuthToken();
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/ekyc/status/$userId'),
      headers: _buildHeaders(token),
    );

    final body = _decodeBody(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    throw Exception(
      body['errorMsg'] ??
          body['message'] ??
          'Không lấy được trạng thái KYC (${response.statusCode})',
    );
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(body);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }
}

final ekycRepositoryProvider = Provider<EkycRepository>((ref) {
  return EkycRepository();
});
