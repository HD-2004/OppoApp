import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/errors/auth_failure.dart';

class PasswordResetApi {
  PasswordResetApi({http.Client? client, this.baseUrl = defaultBaseUrl})
    : _client = client ?? http.Client();

  static const defaultBaseUrl = String.fromEnvironment(
    'PASSWORD_RESET_API_BASE_URL',
    defaultValue:
        'https://sd7ds72m8g.execute-api.ap-southeast-1.amazonaws.com/prod',
  );

  final http.Client _client;
  final String baseUrl;

  Future<void> requestOtp({required String email}) async {
    final response = await _post('/auth/password-reset/request', {
      'email': email.trim(),
    });
    if (response.statusCode != 200) {
      throw _mapFailure(response);
    }
  }

  Future<String> verifyOtp({required String email, required String otp}) async {
    final response = await _post('/auth/password-reset/verify', {
      'email': email.trim(),
      'otp': otp.trim(),
    });
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['resetToken'] as String;
    }
    throw _mapFailure(response);
  }

  Future<void> confirmResetPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    final response = await _post('/auth/password-reset/confirm', {
      'email': email.trim(),
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
    if (response.statusCode != 200) {
      throw _mapFailure(response);
    }
  }

  Future<http.Response> _post(String path, Map<String, String> body) {
    return _client.post(
      Uri.parse('$baseUrl$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
  }

  AuthFailure _mapFailure(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final detail = body['detail']?.toString();
      if (detail == 'invalid_or_expired_otp') {
        return const AuthFailure(
          'Mã OTP không đúng hoặc đã hết hạn.',
          code: 'invalid_or_expired_otp',
        );
      }
      if (detail == 'invalid_or_expired_reset_session') {
        return const AuthFailure(
          'Phiên đổi mật khẩu đã hết hạn. Vui lòng xác thực OTP lại.',
          code: 'invalid_or_expired_reset_session',
        );
      }
      if (detail == 'weak_password') {
        return const AuthFailure(
          'Mật khẩu không đáp ứng yêu cầu bảo mật.',
          code: 'weak_password',
        );
      }
    } catch (_) {
      // Fall through to generic reset-password error.
    }
    return const AuthFailure(
      'Không thể đặt lại mật khẩu. Vui lòng thử lại.',
      code: 'password_reset_failed',
    );
  }
}
