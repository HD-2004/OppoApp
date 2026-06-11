import 'dart:async';
import 'dart:convert';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../shared/platform/network_status.dart';
import '../domain/application_repository.dart';

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return AwsApplicationRepository();
});

Map<String, dynamic> buildCompletionConfirmationPayload(DateTime confirmedAt) {
  return {
    'status': 'completed',
    'candidateConfirmed': true,
    'candidateConfirmedAt': confirmedAt.toUtc().toIso8601String(),
  };
}

Map<String, dynamic> buildCandidateRatingPayload(
  Map<String, dynamic> candidateRating,
) {
  return {'status': 'completed', 'candidateRating': candidateRating};
}

class AwsApplicationRepository implements ApplicationRepository {
  static const _cvBaseUrl =
      'https://v56v542h8f.execute-api.ap-southeast-1.amazonaws.com/prod';
  static const _applicationsBaseUrl =
      'https://l1636ie205.execute-api.ap-southeast-1.amazonaws.com';
  static const _notificationsBaseUrl =
      'https://iuo7ofruu6.execute-api.ap-southeast-1.amazonaws.com';

  static const _maxCvSizeBytes = 5 * 1024 * 1024;

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
            return list
                .map((item) => Map<String, dynamic>.from(item as Map))
                .toList();
          } else if (body['cvUrl'] != null) {
            return [
              {
                'id': '1',
                'cvUrl': body['cvUrl'],
                'cvFileName': body['cvFileName'] ?? 'CV.pdf',
                'cvUploadDate': body['cvUploadDate'] ?? '',
              },
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
  Future<Map<String, dynamic>> uploadCandidateCV({
    required String userId,
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
  }) async {
    if (fileBytes.isEmpty) {
      throw Exception('File CV đang trống.');
    }
    if (fileBytes.length > _maxCvSizeBytes) {
      throw Exception('File không được vượt quá 5MB.');
    }

    const allowedTypes = {
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    if (!allowedTypes.contains(fileType)) {
      throw Exception('Chỉ chấp nhận file PDF, DOC, DOCX.');
    }

    final token = await _getAuthToken();
    final response = await http.post(
      Uri.parse('$_cvBaseUrl/cv/upload'),
      headers: _buildHeaders(token),
      body: jsonEncode({
        'userId': userId,
        'fileName': fileName,
        'fileContent': base64Encode(fileBytes),
        'fileType': fileType,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body);
      final errorMsg = body['error'] ?? body['message'] ?? 'Upload CV thất bại';
      throw Exception(errorMsg);
    }

    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) {
      return body;
    }
    return {'success': true};
  }

  @override
  Future<void> deleteCandidateCV({required String userId, String? cvId}) async {
    final token = await _getAuthToken();
    final encodedCvId = cvId != null ? Uri.encodeComponent(cvId) : null;
    final url = encodedCvId == null
        ? '$_cvBaseUrl/cv/$userId'
        : '$_cvBaseUrl/cv/$userId/$encodedCvId';

    final response = await http.delete(
      Uri.parse(url),
      headers: _buildHeaders(token),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final body = jsonDecode(response.body);
      final errorMsg = body['error'] ?? body['message'] ?? 'Xóa CV thất bại';
      throw Exception(errorMsg);
    }
  }

  @override
  Future<void> submitApplication({
    required String jobId,
    required String cvUrl,
    required String cvFilename,
    required ApplicationNotificationDetails notification,
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
      final errorMsg =
          body['error'] ?? body['message'] ?? 'Failed to submit application';
      throw Exception(errorMsg);
    }

    await _sendEmployerApplicationNotification(
      jobId: jobId,
      details: notification,
    );
  }

  Future<void> _sendEmployerApplicationNotification({
    required String jobId,
    required ApplicationNotificationDetails details,
  }) async {
    if (details.employerId.trim().isEmpty) {
      safePrint(
        'Application notification skipped: employerId is missing for $jobId',
      );
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$_notificationsBaseUrl/notifications'),
        headers: const {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(
          buildEmployerApplicationNotification(jobId: jobId, details: details),
        ),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        safePrint(
          'Failed to send employer application notification '
          '(${response.statusCode}): ${response.body}',
        );
      }
    } catch (error) {
      safePrint('Error sending employer application notification: $error');
    }
  }

  static Map<String, dynamic> buildEmployerApplicationNotification({
    required String jobId,
    required ApplicationNotificationDetails details,
  }) {
    final candidateName = details.candidateName.trim().isNotEmpty
        ? details.candidateName.trim()
        : 'Ứng viên';
    final jobTitle = details.jobTitle.trim().isNotEmpty
        ? details.jobTitle.trim()
        : 'vị trí mới';
    final companyName = details.companyName.trim().isNotEmpty
        ? details.companyName.trim()
        : 'công ty của bạn';

    return {
      'type': 'application',
      'title': 'Ứng viên mới ứng tuyển',
      'titleEn': 'New application received',
      'message':
          '$candidateName đã ứng tuyển vào vị trí $jobTitle tại $companyName.',
      'messageEn': '$candidateName applied for $jobTitle at $companyName.',
      'recipientId': details.employerId,
      'recipientRole': 'employer',
      'senderId': details.candidateId,
      'senderName': candidateName,
      'data': {
        'jobId': jobId,
        'jobTitle': jobTitle,
        'companyName': companyName,
        'candidateId': details.candidateId,
        'candidateName': candidateName,
        'isQuickJob': details.isQuickJob,
      },
      'icon': 'user-plus',
      'color': '#3b82f6',
      'actionUrl': details.isQuickJob
          ? '/employer/quick-jobs'
          : '/employer/standard-jobs',
      'actionText': 'Xem hồ sơ',
      'actionTextEn': 'View applications',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getCandidateApplications(
    String userId,
  ) async {
    if (!isNetworkOnline) {
      return [];
    }

    try {
      final token = await _getAuthToken();
      final response = await http
          .get(
            Uri.parse('$_applicationsBaseUrl/applications/candidate/$userId'),
            headers: _buildHeaders(token),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['applications'] != null) {
          final list = body['applications'] as List;
          return list
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }
      }
      return [];
    } on TimeoutException {
      return [];
    } on http.ClientException {
      return [];
    } catch (e) {
      safePrint('Error fetching candidate applications: $e');
      return [];
    }
  }

  @override
  Future<void> confirmApplicationCompletion({
    required String applicationId,
    required DateTime confirmedAt,
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Vui lòng đăng nhập để xác nhận hoàn thành công việc.');
    }

    final response = await http.put(
      Uri.parse('$_applicationsBaseUrl/applications/$applicationId/status'),
      headers: _buildHeaders(token),
      body: jsonEncode(buildCompletionConfirmationPayload(confirmedAt)),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final errorMsg =
          body['error'] ??
          body['message'] ??
          'Không thể xác nhận hoàn thành công việc';
      throw Exception(errorMsg);
    }
  }

  @override
  Future<void> submitCandidateRating({
    required String applicationId,
    required Map<String, dynamic> candidateRating,
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Vui lòng đăng nhập để đánh giá nhà tuyển dụng.');
    }

    final response = await http.put(
      Uri.parse('$_applicationsBaseUrl/applications/$applicationId/status'),
      headers: _buildHeaders(token),
      body: jsonEncode(buildCandidateRatingPayload(candidateRating)),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final errorMsg =
          body['error'] ??
          body['message'] ??
          'Không thể gửi đánh giá nhà tuyển dụng';
      throw Exception(errorMsg);
    }
  }

  @override
  Future<void> updateApplicationChat({
    required String applicationId,
    required String status,
    required List<Map<String, dynamic>> chatMessages,
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Vui lòng đăng nhập để thực hiện hành động này.');
    }

    final response = await http.put(
      Uri.parse('$_applicationsBaseUrl/applications/$applicationId/status'),
      headers: _buildHeaders(token),
      body: jsonEncode({'status': status, 'chatMessages': chatMessages}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final errorMsg =
          body['error'] ?? body['message'] ?? 'Lỗi khi cập nhật tin nhắn';
      throw Exception(errorMsg);
    }
  }
}
