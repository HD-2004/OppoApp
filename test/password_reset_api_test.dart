import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oppo_temp_jobs/core/errors/auth_failure.dart';
import 'package:oppo_temp_jobs/features/auth/data/password_reset_api.dart';

void main() {
  test('verifyOtp returns reset token', () async {
    final api = PasswordResetApi(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/auth/password-reset/verify');
        expect(jsonDecode(request.body), {
          'email': 'user@example.com',
          'otp': '123456',
        });
        return http.Response(jsonEncode({'resetToken': 'token-123'}), 200);
      }),
    );

    final token = await api.verifyOtp(
      email: ' user@example.com ',
      otp: '123456',
    );

    expect(token, 'token-123');
  });

  test('maps invalid otp error to auth failure message', () async {
    final api = PasswordResetApi(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        return http.Response(
          jsonEncode({'detail': 'invalid_or_expired_otp'}),
          400,
        );
      }),
    );

    expect(
      () => api.verifyOtp(email: 'user@example.com', otp: '000000'),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'message',
          'Mã OTP không đúng hoặc đã hết hạn.',
        ),
      ),
    );
  });
}
