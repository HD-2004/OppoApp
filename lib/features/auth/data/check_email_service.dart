import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';

/// Kết quả kiểm tra email từ API.
enum EmailCheckProvider {
  /// Email chưa tồn tại trong hệ thống.
  notFound,

  /// Email đã đăng ký bằng Google (federated).
  google,

  /// Email đã đăng ký bằng email/password (native).
  native,
}

class EmailCheckResult {
  const EmailCheckResult({required this.exists, this.provider});

  final bool exists;
  final EmailCheckProvider? provider;

  /// Shorthand
  bool get isGoogle => provider == EmailCheckProvider.google;
  bool get isNative => provider == EmailCheckProvider.native;
}

/// Service gọi API GET `/auth/check-email?email=<email>`
/// Dùng chung cho cả màn Đăng ký và Đăng nhập.
class CheckEmailService {
  // ignore: prefer_initializing_formals
  const CheckEmailService({http.Client? client}) : _client = client;

  final http.Client? _client;

  /// Kiểm tra email.
  /// Throws [CheckEmailException] nếu lỗi mạng hoặc server.
  Future<EmailCheckResult> check(String email) async {
    final uri = Uri.parse(checkEmailApiBaseUrl).replace(
      path: '/auth/check-email',
      queryParameters: {'email': email.trim()},
    );

    try {
      final client = _client ?? http.Client();
      final response = await client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw CheckEmailException(
          'Server trả về lỗi ${response.statusCode}',
          code: 'server_error',
        );
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final exists = body['exists'] as bool? ?? false;

      if (!exists) {
        return const EmailCheckResult(
          exists: false,
          provider: EmailCheckProvider.notFound,
        );
      }

      final providerStr = (body['provider'] as String?)?.toLowerCase();
      final provider = switch (providerStr) {
        'google' => EmailCheckProvider.google,
        'native' => EmailCheckProvider.native,
        _ => EmailCheckProvider.native,
      };

      return EmailCheckResult(exists: true, provider: provider);
    } on CheckEmailException {
      rethrow;
    } catch (e) {
      throw CheckEmailException(
        'Không thể kiểm tra email. Vui lòng kiểm tra kết nối mạng.',
        code: 'network_error',
      );
    }
  }
}

class CheckEmailException implements Exception {
  const CheckEmailException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
