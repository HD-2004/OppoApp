import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../../shared/platform/network_status.dart';

typedef NotificationTokenProvider = Future<String?> Function();
typedef NotificationUserIdProvider = Future<String?> Function();

class NotificationRemoteDataSource {
  NotificationRemoteDataSource({
    http.Client? client,
    String? baseUrl,
    NotificationTokenProvider? tokenProvider,
    NotificationUserIdProvider? userIdProvider,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? _defaultBaseUrl,
       // ignore: prefer_initializing_formals
       _tokenProvider = tokenProvider,
       // ignore: prefer_initializing_formals
       _userIdProvider = userIdProvider;

  static const _defaultBaseUrl = String.fromEnvironment(
    'NOTIFICATIONS_API_URL',
    defaultValue: 'https://iuo7ofruu6.execute-api.ap-southeast-1.amazonaws.com',
  );

  final http.Client _client;
  final String _baseUrl;
  final NotificationTokenProvider? _tokenProvider;
  final NotificationUserIdProvider? _userIdProvider;

  Future<Map<String, dynamic>> listNotifications({
    String status = 'all',
    int limit = 20,
    String? nextToken,
  }) async {
    _ensureOnline();
    final userId = await _requireCurrentUserId();
    final query = <String, String>{
      'recipientRole': 'candidate',
      'recipientId': userId,
      'status': status,
      'limit': '$limit',
      // ignore: use_null_aware_elements
      if (nextToken != null) 'nextToken': nextToken,
    };
    final uri = Uri.parse(
      '$_baseUrl/notifications',
    ).replace(queryParameters: query);
    final response = await _client.get(uri, headers: await _headers());
    final decoded = _decodeResponse(response);
    return _normalizeNotificationList(
      decoded,
      recipientId: userId,
      status: status,
      limit: limit,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    _ensureOnline();
    final uri = Uri.parse(
      '$_baseUrl/notifications/${Uri.encodeComponent(notificationId)}',
    );
    final response = await _client.put(
      uri,
      headers: await _headers(),
      body: jsonEncode({'read': true}),
    );
    _decodeResponse(response);
  }

  Future<void> markAllAsRead() async {
    _ensureOnline();
    final userId = await _requireCurrentUserId();
    final uri = Uri.parse(
      '$_baseUrl/notifications/mark-all-read/${Uri.encodeComponent(userId)}',
    );
    final response = await _client.put(uri, headers: await _headers());
    _decodeResponse(response);
  }

  Future<void> archive(String notificationId) async {
    _ensureOnline();
    final uri = Uri.parse(
      '$_baseUrl/notifications/${Uri.encodeComponent(notificationId)}',
    );
    final response = await _client.delete(uri, headers: await _headers());
    _decodeResponse(response);
  }

  void _ensureOnline() {
    if (!isNetworkOnline) {
      throw StateError('Network is offline.');
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await _authToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<String?> _authToken() async {
    final tokenProvider = _tokenProvider;
    if (tokenProvider != null) {
      return tokenProvider();
    }

    try {
      final cognitoPlugin = Amplify.Auth.getPlugin(
        AmplifyAuthCognito.pluginKey,
      );
      final session = await cognitoPlugin.fetchAuthSession();
      return session.userPoolTokensResult.valueOrNull?.idToken.raw;
    } catch (error) {
      safePrint('Notification auth token unavailable: $error');
      return null;
    }
  }

  Future<String> _requireCurrentUserId() async {
    final userId = (await _currentUserId())?.trim();
    if (userId == null || userId.isEmpty) {
      throw StateError('Current candidate id is unavailable.');
    }
    return userId;
  }

  Future<String?> _currentUserId() async {
    final userIdProvider = _userIdProvider;
    if (userIdProvider != null) {
      return userIdProvider();
    }

    try {
      final cognitoPlugin = Amplify.Auth.getPlugin(
        AmplifyAuthCognito.pluginKey,
      );
      final session = await cognitoPlugin.fetchAuthSession();
      final subject =
          session.userPoolTokensResult.valueOrNull?.idToken.claims.subject;
      if (subject != null && subject.isNotEmpty) {
        return subject;
      }
    } catch (error) {
      safePrint('Notification user id unavailable from token: $error');
    }

    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user.userId;
    } catch (error) {
      safePrint('Notification user id unavailable: $error');
      return null;
    }
  }

  Object? _decodeResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['error']?.toString() ?? decoded['message']?.toString()
          : null;
      throw Exception(
        message ?? 'Notification request failed (${response.statusCode})',
      );
    }
    return decoded;
  }

  Map<String, dynamic> _normalizeNotificationList(
    Object? decoded, {
    required String recipientId,
    required String status,
    required int limit,
  }) {
    final rawItems = _extractItems(decoded);
    final items = rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where(
          (item) =>
              _isVisibleCandidateNotification(item, recipientId) &&
              _matchesStatus(item, status),
        )
        .take(limit)
        .toList(growable: false);

    return {
      'items': items,
      'summary': {
        'total': items.length,
        'unread': items.where(_isUnread).length,
      },
      if (decoded is Map) 'nextToken': decoded['nextToken'],
    };
  }

  List<dynamic> _extractItems(Object? decoded) {
    if (decoded is List) {
      return decoded;
    }
    if (decoded is Map) {
      final rawItems = decoded['items'] ?? decoded['notifications'];
      if (rawItems is List) {
        return rawItems;
      }
      final data = decoded['data'];
      if (data is List) {
        return data;
      }
      if (data is Map) {
        final dataItems = data['items'] ?? data['notifications'];
        if (dataItems is List) {
          return dataItems;
        }
      }
    }
    return const [];
  }

  bool _isVisibleCandidateNotification(
    Map<String, dynamic> item,
    String recipientId,
  ) {
    if (_truthy(item['deleted']) ||
        _truthy(item['isDeleted']) ||
        item['deletedAt'] != null) {
      return false;
    }

    final role = item['recipientRole']?.toString().trim().toLowerCase();
    if (role != 'candidate') {
      return false;
    }

    final itemRecipientId = item['recipientId']?.toString().trim();
    return itemRecipientId == recipientId;
  }

  bool _matchesStatus(Map<String, dynamic> item, String status) {
    final expectedStatus = status.trim().toLowerCase();
    if (expectedStatus.isEmpty || expectedStatus == 'all') {
      return true;
    }
    return _statusFor(item) == expectedStatus;
  }

  bool _isUnread(Map<String, dynamic> item) {
    return _statusFor(item) == 'unread';
  }

  String _statusFor(Map<String, dynamic> item) {
    final status = item['status']?.toString().trim().toLowerCase();
    if (status == 'read' || status == 'unread' || status == 'archived') {
      return status!;
    }
    if (_truthy(item['read']) || item['readAt'] != null) {
      return 'read';
    }
    return 'unread';
  }

  bool _truthy(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }
}
