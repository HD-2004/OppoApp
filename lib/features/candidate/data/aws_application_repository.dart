import 'dart:convert';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/application_repository.dart';

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return AwsApplicationRepository();
});

class AwsApplicationRepository implements ApplicationRepository {
  static const _cvBaseUrl = 'https://v56v542h8f.execute-api.ap-southeast-1.amazonaws.com/prod';
  static const _applicationsBaseUrl = 'https://l1636ie205.execute-api.ap-southeast-1.amazonaws.com';

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
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getCandidateCVs(String userId) async {
    try {
      final token = await _getAuthToken();
      final response = await http.get(
        Uri.parse('$_cvBaseUrl/cv/$userId'),
        headers: _buildHeaders(token),
      );

      if (response.statusCode == 404) {
        return [];
      }

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          if (body['cvList'] != null) {
            final list = body['cvList'] as List;
            return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
          } else if (body['cvUrl'] != null) {
            return [
              {
                'id': '1',
                'cvUrl': body['cvUrl'],
                'cvFileName': body['cvFileName'] ?? 'CV.pdf',
                'cvUploadDate': body['cvUploadDate'] ?? '',
              }
            ];
          }
        }
      }
      return [];
    } catch (e) {
      safePrint('Error fetching CV info: $e');
      return [];
    }
  }

  @override
  Future<void> submitApplication({
    required String jobId,
    required String cvUrl,
    required String cvFilename,
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Vui lòng đăng nhập để ứng tuyển.');
    }

    final response = await http.post(
      Uri.parse('$_applicationsBaseUrl/applications'),
      headers: _buildHeaders(token),
      body: jsonEncode({
        'jobId': jobId,
        'cvUrl': cvUrl,
        'cvFilename': cvFilename,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body);
      final errorMsg = body['error'] ?? body['message'] ?? 'Failed to submit application';
      throw Exception(errorMsg);
    }
  }
}
