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
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _encodeBody(Map<String, dynamic> body) {
    body.removeWhere((_, value) => value == null);
    return jsonEncode(body);
  }

  /// OCR ID Card Front & optional Back images
  /// both should be base64 data URLs: "data:image/jpeg;base64,..."
  Future<Map<String, dynamic>> ocrCCCD({
    required String imageFront,
    String? imageBack,
  }) async {
    final token = await _getAuthToken();
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/ekyc/ocr'),
      headers: _buildHeaders(token),
      body: _encodeBody({'imageFront': imageFront, 'imageBack': imageBack}),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body;
    } else {
      throw Exception(
        body['errorMsg'] ?? 'OCR failed (${response.statusCode})',
      );
    }
  }

  /// Face matching & Liveness verification
  Future<Map<String, dynamic>> verifyFace({
    required String faceImage,
    String? frontHash,
    String? frontToken,
  }) async {
    final token = await _getAuthToken();
    final response = await http.post(
      Uri.parse('$_apiBaseUrl/ekyc/verify-face'),
      headers: _buildHeaders(token),
      body: _encodeBody({
        'faceImage': faceImage,
        'front_hash': frontHash,
        'front_token': frontToken,
      }),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body;
    } else {
      throw Exception(
        body['errorMsg'] ?? 'Face verification failed (${response.statusCode})',
      );
    }
  }

  /// Fetch candidate's current KYC status
  Future<Map<String, dynamic>> getKycStatus(String userId) async {
    final token = await _getAuthToken();
    final response = await http.get(
      Uri.parse('$_apiBaseUrl/ekyc/status/$userId'),
      headers: _buildHeaders(token),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return body;
    } else {
      throw Exception(
        body['errorMsg'] ?? 'Failed to get KYC status (${response.statusCode})',
      );
    }
  }
}

final ekycRepositoryProvider = Provider<EkycRepository>((ref) {
  return EkycRepository();
});
