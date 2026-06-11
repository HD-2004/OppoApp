import 'dart:convert';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../../shared/platform/network_status.dart';

class NotificationRemoteDataSource {
  NotificationRemoteDataSource({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl;

  static const _defaultBaseUrl = String.fromEnvironment(
    'NOTIFICATIONS_API_URL',
    defaultValue: 'https://iuo7ofruu6.execute-api.ap-southeast-1.amazonaws.com',
  );

  final http.Client _client;
  final String _baseUrl;

  Future<Map<String, dynamic>> listNotifications({
    String status = 'all',
    int limit = 20,
    String? nextToken,
  }) async {
    final query = <String, String>{
      'status': status,
      'limit': '$limit',
      // ignore: use_null_aware_elements
      if (nextToken != null) 'nextToken': nextToken,
    };
    _ensureOnline();
    final uri = Uri.parse(
      '$_baseUrl/candidate/notifications',
    ).replace(queryParameters: query);
    final response = await _client.get(uri, headers: await _headers());
    return _decodeResponse(response);
  }

  Future<void> markAsRead(String notificationId) async {
    _ensureOnline();
    final uri = Uri.parse(
      '$_baseUrl/candidate/notifications/$notificationId/read',
    );
    final response = await _client.patch(uri, headers: await _headers());
    _decodeResponse(response);
  }

  Future<void> markAllAsRead() async {
    _ensureOnline();
    final uri = Uri.parse('$_baseUrl/candidate/notifications/read-all');
    final response = await _client.patch(uri, headers: await _headers());
    _decodeResponse(response);
  }

  Future<void> archive(String notificationId) async {
    _ensureOnline();
    final uri = Uri.parse(
      '$_baseUrl/candidate/notifications/$notificationId/archive',
    );
    final response = await _client.patch(uri, headers: await _headers());
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

  Map<String, dynamic> _decodeResponse(http.Response response) {
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
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }
}
