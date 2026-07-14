import 'dart:async';
import 'dart:convert';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../shared/platform/network_status.dart';
import '../domain/application_repository.dart';

final applicationRepositoryProvider = Provider<ApplicationRepository>((ref) {
  return AwsApplicationRepository();
});

Map<String, dynamic> buildCompletionConfirmationPayload(DateTime confirmedAt) {
  final archivedAt = confirmedAt.toUtc().toIso8601String();
  return {
    'status': 'completed',
    'candidateConfirmed': true,
    'candidateConfirmedAt': archivedAt,
    'chatStatus': 'archived',
    'chatArchivedAt': archivedAt,
    'chatClosedAt': archivedAt,
  };
}

Map<String, dynamic> buildChatArchivePayload(DateTime archivedAt) {
  final timestamp = archivedAt.toUtc().toIso8601String();
  return {
    'status': 'archived',
    'chatStatus': 'archived',
    'archivedAt': timestamp,
    'chatArchivedAt': timestamp,
    'closedAt': timestamp,
    'chatClosedAt': timestamp,
  };
}

Map<String, dynamic> buildCandidateRatingPayload(
  Map<String, dynamic> candidateRating,
) {
  return {'status': 'completed', 'candidateRating': candidateRating};
}

Map<String, dynamic> buildApplicationStatusPayload({
  required String status,
  Map<String, dynamic> extraFields = const {},
}) {
  return {'status': status, ...extraFields};
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
        Uri.parse(resolveUrl('$_cvBaseUrl/cv/$userId')),
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
    } catch (_) {
      rethrow;
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
      Uri.parse(resolveUrl('$_cvBaseUrl/cv/upload')),
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
      Uri.parse(resolveUrl(url)),
      headers: _buildHeaders(token),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final body = jsonDecode(response.body);
      final errorMsg = body['error'] ?? body['message'] ?? 'Xóa CV thất bại';
      throw Exception(errorMsg);
    }
  }

  @override
  Future<Map<String, dynamic>> submitApplication({
    required String jobId,
    required String cvUrl,
    required String cvFilename,
    required ApplicationNotificationDetails notification,
    String? cvS3Key,
    Map<String, dynamic>? extraFields,
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Vui lòng đăng nhập để ứng tuyển.');
    }

    final Map<String, dynamic> requestBody = {
      'jobId': jobId,
      'cvUrl': cvUrl,
      'cvFilename': cvFilename,
      // ignore: use_null_aware_elements
      if (cvS3Key != null) 'cvS3Key': cvS3Key,
    };
    if (extraFields != null) {
      requestBody.addAll(extraFields);
    }

    final response = await http.post(
      Uri.parse(resolveUrl('$_applicationsBaseUrl/applications')),
      headers: _buildHeaders(token),
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body);
      final errorMsg =
          body['error'] ?? body['message'] ?? 'Failed to submit application';
      throw Exception(errorMsg);
    }

    final successBody = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);

    await _sendEmployerApplicationNotification(
      jobId: jobId,
      details: notification,
    );

    if (successBody is Map<String, dynamic>) {
      return successBody;
    }
    if (successBody is Map) {
      return Map<String, dynamic>.from(successBody);
    }
    return <String, dynamic>{};
  }

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
        resolveUrl(
          '$_applicationsBaseUrl/applications/'
          '${Uri.encodeComponent(applicationId)}/status',
        ),
      ),
      headers: _buildHeaders(token),
      body: jsonEncode(
        buildApplicationStatusPayload(status: status, extraFields: extraFields),
      ),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final errorMsg =
          body['error'] ??
          body['message'] ??
          'Không thể cập nhật hồ sơ ứng tuyển';
      throw Exception(errorMsg);
    }
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
        Uri.parse(resolveUrl('$_notificationsBaseUrl/notifications')),
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
            Uri.parse(resolveUrl('$_applicationsBaseUrl/applications/candidate/$userId')),
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
      Uri.parse(resolveUrl('$_applicationsBaseUrl/applications/$applicationId/status')),
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
      Uri.parse(resolveUrl('$_applicationsBaseUrl/applications/$applicationId/status')),
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
      Uri.parse(resolveUrl('$_applicationsBaseUrl/applications/$applicationId/status')),
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

  @override
  Future<void> archiveApplicationChat({
    required String applicationId,
    required DateTime archivedAt,
  }) async {
    final token = await _getAuthToken();
    if (token == null) {
      throw Exception('Vui lòng đăng nhập để thực hiện hành động này.');
    }

    final response = await http.put(
      Uri.parse(resolveUrl('$_applicationsBaseUrl/applications/$applicationId/status')),
      headers: _buildHeaders(token),
      body: jsonEncode(buildChatArchivePayload(archivedAt)),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final errorMsg =
          body['error'] ??
          body['message'] ??
          'Không thể lưu trữ cuộc trò chuyện';
      throw Exception(errorMsg);
    }
  }

  @override
  Future<void> sendCandidateAiScreeningPassedNotification({
    required String candidateId,
    required String jobTitle,
    required String companyName,
    required String jobId,
    required int score,
  }) async {
    if (candidateId.trim().isEmpty) return;

    final safeJobTitle = jobTitle.trim().isNotEmpty ? jobTitle.trim() : 'công việc';
    final safeCompanyName = companyName.trim().isNotEmpty ? companyName.trim() : 'Nhà tuyển dụng';

    try {
      final response = await http.post(
        Uri.parse(resolveUrl('$_notificationsBaseUrl/notifications')),
        headers: const {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'type': 'ai_screening_passed',
          'title': 'Hồ sơ ứng tuyển đã qua sàng lọc AI',
          'titleEn': 'Your CV passed AI screening',
          'message': 'CV của bạn cho vị trí $safeJobTitle tại $safeCompanyName đã qua vòng sơ loại AI và đang chờ Nhà tuyển dụng xét duyệt.',
          'messageEn': 'Your CV for the $safeJobTitle position at $safeCompanyName has passed the AI screening and is pending employer review.',
          'recipientId': candidateId,
          'recipientRole': 'candidate',
          'senderId': 'system',
          'senderName': 'Hệ thống AI',
          'data': {
            'jobId': jobId,
            'jobTitle': safeJobTitle,
            'companyName': safeCompanyName,
            'score': score,
            'stage': 'ai_passed',
          },
          'icon': 'check-circle',
          'color': '#10b981',
          'actionUrl': '/candidate/jobs?tab=standard',
          'actionText': 'Xem trạng thái hồ sơ',
          'actionTextEn': 'View application status',
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        safePrint(
          'Failed to send candidate AI screening passed notification '
          '(${response.statusCode}): ${response.body}',
        );
      }
    } catch (error) {
      safePrint('Error sending candidate AI screening passed notification: $error');
    }
  }

  @override
  Future<void> sendCandidateAiScreeningRejectedNotification({
    required String candidateId,
    required String jobTitle,
    required String companyName,
    required String jobId,
  }) async {
    if (candidateId.trim().isEmpty) return;

    final safeJobTitle = jobTitle.trim().isNotEmpty ? jobTitle.trim() : 'công việc';
    final safeCompanyName = companyName.trim().isNotEmpty ? companyName.trim() : 'Nhà tuyển dụng';

    try {
      final response = await http.post(
        Uri.parse(resolveUrl('$_notificationsBaseUrl/notifications')),
        headers: const {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'type': 'ai_screening_rejected',
          'title': 'Hồ sơ không qua sàng lọc AI',
          'titleEn': 'Your CV did not pass AI screening',
          'message': 'Rất tiếc, CV ứng tuyển vị trí $safeJobTitle tại $safeCompanyName của bạn chưa phù hợp ở vòng sơ loại AI. Hãy cập nhật thêm kỹ năng và thử sức với các cơ hội khác nhé!',
          'messageEn': 'Unfortunately, your CV for the $safeJobTitle position at $safeCompanyName did not meet the AI screening criteria. Update your skills and try other opportunities!',
          'recipientId': candidateId,
          'recipientRole': 'candidate',
          'senderId': 'system',
          'senderName': 'Hệ thống AI',
          'data': {
            'jobId': jobId,
            'jobTitle': safeJobTitle,
            'companyName': safeCompanyName,
            'stage': 'ai_rejected',
          },
          'icon': 'alert-circle',
          'color': '#ef4444',
          'actionUrl': '/candidate/jobs?tab=standard',
          'actionText': 'Xem việc làm khác',
          'actionTextEn': 'Browse other jobs',
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        safePrint(
          'Failed to send candidate AI screening rejected notification '
          '(${response.statusCode}): ${response.body}',
        );
      }
    } catch (error) {
      safePrint('Error sending candidate AI screening rejected notification: $error');
    }
  }
}
