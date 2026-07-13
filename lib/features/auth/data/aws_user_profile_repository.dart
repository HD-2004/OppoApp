import 'dart:convert';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../shared/domain/app_role.dart';
import '../domain/auth_user_profile.dart';
import 'user_profile_repository.dart';

Map<String, dynamic> buildProfileCreatePayload({
  required String userId,
  required String email,
  required String fullName,
  required AppRole? role,
  required DateTime createdAt,
  String? dateOfBirth,
}) {
  final now = createdAt.toIso8601String();
  return {
    'userId': userId,
    'email': email.trim(),
    'fullName': fullName.trim(),
    'role': (role ?? AppRole.candidate).cognitoValue,
    if (dateOfBirth?.trim().isNotEmpty == true)
      'dateOfBirth': dateOfBirth!.trim(),
    'kycCompleted': false,
    'profileCompleted': false,
    'createdAt': now,
    'updatedAt': now,
  };
}

Map<String, dynamic> buildQuickJobActivationRequestNotification({
  required AuthUserProfile user,
  required DateTime submittedAt,
}) {
  final submittedAtIso = submittedAt.toUtc().toIso8601String();
  final senderName = user.fullName.trim().isNotEmpty
      ? user.fullName.trim()
      : (user.email.trim().isNotEmpty ? user.email.trim() : 'Ứng viên');

  return {
    'type': 'quick_job_activation_request',
    'title': 'Yêu cầu kích hoạt Công việc tuyển gấp',
    'titleEn': 'Urgent jobs activation request',
    'message':
        '$senderName đã gửi yêu cầu kích hoạt Công việc tuyển gấp và đang chờ admin duyệt.',
    'messageEn':
        '$senderName requested urgent jobs activation and is waiting for admin review.',
    'recipientId': 'admin',
    'recipientRole': 'admin',
    'senderId': user.userId,
    'senderName': senderName,
    'data': {
      'candidateId': user.userId,
      'candidateName': senderName,
      'candidateEmail': user.email,
      'verificationStatus': 'SUBMITTED',
      'verificationSubmittedAt': submittedAtIso,
    },
    'icon': 'shield',
    'color': '#2563eb',
    'actionUrl': '/admin/candidates',
    'actionText': 'Duyệt yêu cầu',
    'actionTextEn': 'Review request',
  };
}

class AwsUserProfileRepository implements UserProfileRepository {
  AwsUserProfileRepository({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    String profileBaseUrl = _defaultProfileBaseUrl,
    String notificationsBaseUrl = _defaultNotificationsBaseUrl,
    DateTime Function()? nowProvider,
  }) : _client = client ?? http.Client(),
       // ignore: prefer_initializing_formals
       _tokenProvider = tokenProvider,
       // ignore: prefer_initializing_formals
       _profileBaseUrl = profileBaseUrl,
       // ignore: prefer_initializing_formals
       _notificationsBaseUrl = notificationsBaseUrl,
       _nowProvider = nowProvider ?? DateTime.now;

  static const _defaultProfileBaseUrl =
      'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod';
  static const _defaultNotificationsBaseUrl =
      'https://iuo7ofruu6.execute-api.ap-southeast-1.amazonaws.com';

  final http.Client _client;
  final Future<String?> Function()? _tokenProvider;
  final String _profileBaseUrl;
  final String _notificationsBaseUrl;
  final DateTime Function() _nowProvider;

  Future<String?> _getAuthToken() async {
    final tokenProvider = _tokenProvider;
    if (tokenProvider != null) {
      return tokenProvider();
    }

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

  int _utf8Size(String value) => utf8.encode(value).length;

  String _truncateForLog(String value) {
    const maxLength = 500;
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength)}...';
  }

  @override
  Future<void> savePendingRegistration(
    PendingRegistrationProfile profile,
  ) async {
    // No-op for direct DynamoDB flow since registrations are saved on Cognito signup
    // and profile is upserted after login.
  }

  @override
  Future<AuthUserProfile?> getByUserId(String userId) async {
    final token = await _getAuthToken();
    final response = await _client.get(
      Uri.parse(resolveUrl('$_profileBaseUrl/profile/$userId')),
      headers: _buildHeaders(token),
    );

    if (response.statusCode == 404) {
      return null;
    }

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final data = body['data'] as Map<String, dynamic>;
        return _mapJsonToProfile(data, userId);
      }
    }
    throw Exception(
      'Không thể tải hồ sơ từ database (HTTP ${response.statusCode}).',
    );
  }

  @override
  Future<AuthUserProfile?> getByEmail(String email) async {
    final token = await _getAuthToken();
    final encodedEmail = Uri.encodeComponent(email);
    final response = await _client.get(
      Uri.parse(resolveUrl('$_profileBaseUrl/profile/email/$encodedEmail')),
      headers: _buildHeaders(token),
    );

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final data = body['data'] as Map<String, dynamic>;
        return _mapJsonToProfile(data, data['userId'] ?? '');
      }
    }
    throw Exception(
      'Không thể tải hồ sơ từ database (HTTP ${response.statusCode}).',
    );
  }

  @override
  Future<AuthUserProfile> upsertAfterLogin({
    required String userId,
    required String username,
    required String email,
    required String fullName,
    required AppRole? role,
    String? dateOfBirth,
  }) async {
    // 1. Check if profile already exists in DynamoDB
    final existing = await getByUserId(userId);
    if (existing != null) {
      // If email or fullName are empty in the profile but available in cognito, update them
      final shouldFillDateOfBirth =
          (existing.dateOfBirth == null || existing.dateOfBirth!.isEmpty) &&
          dateOfBirth?.trim().isNotEmpty == true;
      if ((existing.fullName.isEmpty && fullName.isNotEmpty) ||
          (existing.email.isEmpty && email.isNotEmpty) ||
          shouldFillDateOfBirth) {
        return updateProfileCompleted(
          userId: userId,
          completed: existing.profileCompleted,
          fullName: existing.fullName.isEmpty ? fullName : existing.fullName,
          dateOfBirth: shouldFillDateOfBirth
              ? dateOfBirth
              : existing.dateOfBirth,
        );
      }
      return existing;
    }

    // 2. Create new profile in DynamoDB
    final token = await _getAuthToken();
    final payload = buildProfileCreatePayload(
      userId: userId,
      email: email,
      fullName: fullName,
      role: role,
      dateOfBirth: dateOfBirth,
      createdAt: DateTime.now(),
    );

    final response = await _client.post(
      Uri.parse(resolveUrl('$_profileBaseUrl/profile')),
      headers: _buildHeaders(token),
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final data = body['data'] as Map<String, dynamic>;
        return _mapJsonToProfile(data, userId);
      }
    }

    throw Exception(
      'Không thể tạo hồ sơ trong database (HTTP ${response.statusCode}).',
    );
  }

  @override
  Future<AuthUserProfile> updateKycCompleted({
    required String userId,
    required bool completed,
  }) async {
    final token = await _getAuthToken();
    final response = await _client.put(
      Uri.parse(resolveUrl('$_profileBaseUrl/profile/$userId')),
      headers: _buildHeaders(token),
      body: jsonEncode({
        'kycCompleted': completed,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final data = body['data'] as Map<String, dynamic>;
        return _mapJsonToProfile(data, userId);
      }
    }

    // Fallback fetch if update response doesn't contain updated profile
    final updated = await getByUserId(userId);
    if (updated != null) return updated;
    throw Exception('Failed to update KYC status in DynamoDB');
  }

  @override
  Future<AuthUserProfile> updateProfileCompleted({
    required String userId,
    required bool completed,
    String? fullName,
    String? phone,
    String? cccd,
    String? dateOfBirth,
    String? location,
    String? title,
    String? bio,
    List<String>? skills,
    String? profileImage,
    Map<String, String>? socialLinks,
    List<String>? savedJobs,
  }) async {
    final token = await _getAuthToken();
    final payload = {
      'profileCompleted': completed,
      if (fullName != null) 'fullName': fullName.trim(),
      if (phone != null) 'phone': phone.trim(),
      if (cccd != null) 'cccd': cccd.trim(),
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.trim(),
      if (location != null) 'location': location.trim(),
      if (title != null) 'title': title.trim(),
      if (bio != null) 'bio': bio.trim(),
      'skills': ?skills,
      'profileImage': ?profileImage,
      'socialLinks': ?socialLinks,
      'savedJobs': ?savedJobs,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    final encodedPayload = jsonEncode(payload);
    final payloadSize = _utf8Size(encodedPayload);
    if (profileImage != null) {
      safePrint(
        'Updating profile with profileImage: '
        'imageChars=${profileImage.length}, payloadBytes=$payloadSize',
      );
    } else {
      safePrint('Updating profile: payloadBytes=$payloadSize');
    }

    final response = await _client.put(
      Uri.parse(resolveUrl('$_profileBaseUrl/profile/$userId')),
      headers: _buildHeaders(token),
      body: encodedPayload,
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final data = body['data'] as Map<String, dynamic>;
        return _mapJsonToProfile(data, userId);
      }
      safePrint(
        'Profile update returned 200 without profile data: '
        '${_truncateForLog(response.body)}',
      );
    }

    final responseSize = _utf8Size(response.body);
    safePrint(
      'Failed to update profile in DynamoDB: '
      'status=${response.statusCode}, payloadBytes=$payloadSize, '
      'responseBytes=$responseSize, body=${_truncateForLog(response.body)}',
    );
    throw Exception(
      'Failed to update profile in DynamoDB '
      '(status ${response.statusCode}, payload $payloadSize bytes)',
    );
  }

  @override
  Future<AuthUserProfile> submitVerificationRequest({
    required String userId,
    AuthUserProfile? currentProfile,
  }) async {
    final submittedAt = _nowProvider();
    final notificationProfile =
        currentProfile ??
        AuthUserProfile(
          userId: userId,
          username: userId,
          role: AppRole.candidate,
          email: '',
          fullName: '',
          kycCompleted: false,
          profileCompleted: false,
        );

    await _sendQuickJobActivationRequest(
      user: notificationProfile,
      submittedAt: submittedAt,
    );

    final token = await _getAuthToken();
    try {
      final submittedAtIso = submittedAt.toUtc().toIso8601String();
      final response = await _client.put(
        Uri.parse(resolveUrl('$_profileBaseUrl/profile/$userId')),
        headers: _buildHeaders(token),
        body: jsonEncode({
          'verificationStatus': 'SUBMITTED',
          'verificationSubmittedAt': submittedAtIso,
          'updatedAt': submittedAtIso,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'] as Map<String, dynamic>;
          return _mapJsonToProfile(data, userId);
        }
      }

      if (currentProfile != null) {
        safePrint(
          'Quick job activation notification sent, but profile status update '
          'returned ${response.statusCode}: ${_truncateForLog(response.body)}',
        );
        return _submittedProfile(currentProfile, submittedAt);
      }

      final updated = await getByUserId(userId);
      if (updated != null) return updated;
      throw Exception('Failed to submit verification request in DynamoDB');
    } catch (error) {
      if (currentProfile != null) {
        safePrint(
          'Quick job activation notification sent, but profile status update '
          'failed: $error',
        );
        return _submittedProfile(currentProfile, submittedAt);
      }
      rethrow;
    }
  }

  Future<void> _sendQuickJobActivationRequest({
    required AuthUserProfile user,
    required DateTime submittedAt,
  }) async {
    final response = await _client.post(
      Uri.parse(resolveUrl('$_notificationsBaseUrl/notifications')),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      },
      body: jsonEncode(
        buildQuickJobActivationRequestNotification(
          user: user,
          submittedAt: submittedAt,
        ),
      ),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Không thể gửi yêu cầu đến admin '
        '(HTTP ${response.statusCode}).',
      );
    }
  }

  AuthUserProfile _submittedProfile(
    AuthUserProfile profile,
    DateTime submittedAt,
  ) {
    return profile.copyWith(
      verificationStatus: 'SUBMITTED',
      updatedAt: submittedAt,
    );
  }

  @override
  Future<AuthUserProfile> updateAvailability({
    required String userId,
    required bool isActive,
    double? latitude,
    double? longitude,
  }) async {
    final token = await _getAuthToken();
    final response = await _client.put(
      Uri.parse(resolveUrl('$_profileBaseUrl/profile/$userId')),
      headers: _buildHeaders(token),
      body: jsonEncode({
        'isActive': isActive,
        'latitude': ?latitude,
        'longitude': ?longitude,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['success'] == true && body['data'] != null) {
        final data = body['data'] as Map<String, dynamic>;
        return _mapJsonToProfile(data, userId);
      }
    }

    final updated = await getByUserId(userId);
    if (updated != null) return updated;
    throw Exception('Failed to update availability in DynamoDB');
  }

  AuthUserProfile _mapJsonToProfile(
    Map<String, dynamic> data,
    String defaultUserId,
  ) {
    final parsedRole = AppRoleParser.fromCognitoValue(data['role'] as String?);

    List<String>? skillsList;
    if (data['skills'] != null) {
      try {
        skillsList = List<String>.from(data['skills'] as List);
      } catch (_) {
        // Fallback or skip if casting fails
      }
    }

    List<String>? savedJobsList;
    if (data['savedJobs'] != null) {
      try {
        savedJobsList = List<String>.from(data['savedJobs'] as List);
      } catch (_) {
        // Fallback or skip if casting fails
      }
    }

    Map<String, String>? socialLinksMap;
    if (data['socialLinks'] != null) {
      try {
        final rawMap = data['socialLinks'] as Map;
        socialLinksMap = rawMap.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      } catch (_) {
        // Fallback or skip if casting fails
      }
    }

    return AuthUserProfile(
      userId: data['userId'] as String? ?? defaultUserId,
      username: data['username'] as String? ?? data['email'] as String? ?? '',
      role: parsedRole,
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      kycCompleted: data['kycCompleted'] == true,
      profileCompleted: data['profileCompleted'] == true,
      phone: data['phone'] as String?,
      cccd: data['cccd'] as String?,
      dateOfBirth: data['dateOfBirth'] as String?,
      location: data['location'] as String?,
      title: data['title'] as String?,
      bio: data['bio'] as String?,
      skills: skillsList,
      education: data['education'] as String?,
      experience: data['experience'] as String?,
      profileImage: data['profileImage'] as String?,
      savedJobs: savedJobsList,
      createdAt: data['createdAt'] != null
          ? DateTime.tryParse(data['createdAt'] as String)
          : null,
      updatedAt: data['updatedAt'] != null
          ? DateTime.tryParse(data['updatedAt'] as String)
          : null,
      verificationStatus: data['verificationStatus'] as String?,
      isActive: data['isActive'] == true,
      latitude: double.tryParse(data['latitude']?.toString() ?? ''),
      longitude: double.tryParse(data['longitude']?.toString() ?? ''),
      socialLinks: socialLinksMap,
    );
  }
}
