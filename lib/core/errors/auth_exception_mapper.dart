import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';

import 'auth_failure.dart';

class AuthExceptionMapper {
  const AuthExceptionMapper._();

  static AuthFailure map(Exception error) {
    if (error is AuthFailure) {
      return error;
    }
    if (error is NetworkException) {
      return const AuthFailure(
        'Lỗi kết nối mạng. Vui lòng kiểm tra internet.',
        code: 'network',
      );
    }
    if (error is SignedOutException) {
      return const AuthFailure('Bạn chưa đăng nhập.', code: 'signed_out');
    }
    if (error is AuthNotAuthorizedException) {
      return const AuthFailure(
        'Email hoặc mật khẩu không đúng.',
        code: 'not_authorized',
      );
    }
    if (error is AuthException) {
      return _mapAuthException(error);
    }

    return const AuthFailure(
      'Đã có lỗi xảy ra. Vui lòng thử lại.',
      code: 'unknown',
    );
  }

  static AuthFailure _mapAuthException(AuthException error) {
    final message = error.message.toLowerCase();
    final typeName = error.runtimeTypeName.toLowerCase();
    final combined = '$typeName $message';

    // Log chi tiết để debug — giúp tìm root cause khi exception bị re-map
    safePrint(
      '[AuthExceptionMapper] type=${error.runtimeTypeName} '
      'message="${error.message}"',
    );

    if (combined.contains('usernotfound') ||
        combined.contains('user not found') ||
        combined.contains('username/client id combination not found')) {
      return const AuthFailure('Email không tồn tại.', code: 'user_not_found');
    }
    if (combined.contains('usernameexists') ||
        combined.contains('already exists') ||
        combined.contains('user already exists')) {
      return const AuthFailure(
        'Email này đã được đăng ký.',
        code: 'email_exists',
      );
    }
    if (combined.contains('notauthorized')) {
      return const AuthFailure(
        'Email hoặc mật khẩu không đúng.',
        code: 'not_authorized',
      );
    }
    if (combined.contains('usernotconfirmed') ||
        combined.contains('not confirmed')) {
      return const AuthFailure(
        'Tài khoản chưa được xác nhận. Vui lòng kiểm tra email.',
        code: 'user_unconfirmed',
      );
    }
    if (combined.contains('codemismatch')) {
      return const AuthFailure(
        'Mã xác nhận không đúng.',
        code: 'code_mismatch',
      );
    }
    if (combined.contains('expiredcode')) {
      return const AuthFailure('Mã xác nhận đã hết hạn.', code: 'expired_code');
    }
    if (combined.contains('limitexceeded') ||
        combined.contains('attempt limit exceeded')) {
      return const AuthFailure(
        'Bạn đã thử quá nhiều lần. Vui lòng thử lại sau.',
        code: 'limit_exceeded',
      );
    }
    if (combined.contains('invalidpassword') ||
        combined.contains('password did not conform') ||
        combined.contains('password')) {
      return const AuthFailure(
        'Mật khẩu không đáp ứng yêu cầu bảo mật.',
        code: 'invalid_password',
      );
    }
    if (combined.contains('invalidparameter')) {
      if (combined.contains('custom:role')) {
        return const AuthFailure(
          'User Pool chưa có custom attribute custom:role hoặc App Client chưa cho phép ghi attribute này.',
          code: 'missing_role_attribute',
        );
      }
      return const AuthFailure(
        'Thông tin nhập vào không hợp lệ.',
        code: 'invalid_parameter',
      );
    }
    if (combined.contains('hosted ui') ||
        combined.contains('oauth') ||
        combined.contains('redirectsignin') ||
        combined.contains('redirectsignout') ||
        combined.contains('socialproviders') ||
        combined.contains('signinwithwebui')) {
      // Log đầy đủ để debug — lỗi thật thường nằm trong underlyingException
      safePrint('[AuthExceptionMapper] social sign-in error branch hit:');
      safePrint('  type              = ${error.runtimeTypeName}');
      safePrint('  message           = ${error.message}');
      safePrint('  recoverySuggestion= ${error.recoverySuggestion}');
      safePrint('  underlyingException = ${error.underlyingException}');
      // Trong debug mode: trả về raw message thay vì chuỗi cố định
      // để lỗi gốc hiện thẳng lên UI cho dễ debug.
      if (kDebugMode) {
        final debugMsg = StringBuffer()
          ..writeln('[DEBUG] Social sign-in thất bại:')
          ..writeln('  type: ${error.runtimeTypeName}')
          ..writeln('  message: ${error.message}');
        if (error.underlyingException != null) {
          debugMsg.writeln('  cause: ${error.underlyingException}');
        }
        return AuthFailure(debugMsg.toString().trim(), code: 'social_debug');
      }
      return AuthFailure.socialSignInConfiguration;
    }
    if (combined.contains('invalid_scope') ||
        combined.contains('invalidscope') ||
        combined.contains('invalid scope')) {
      return const AuthFailure(
        'Scope không hợp lệ. Hãy bật "aws.cognito.signin.user.admin" trong Cognito App Client scopes.',
        code: 'invalid_scope',
      );
    }
    // Only map to configuration error when it's clearly a Cognito setup issue,
    // not a generic exception that happens to contain the word "config".
    // Note: configureAmplify() already throws AuthFailure.configuration directly,
    // so reaching here with a config-related exception is unexpected.
    if (combined.contains('appclientid') ||
        combined.contains('userpool') ||
        (combined.contains('configuration') &&
            combined.contains('amplify'))) {
      return AuthFailure.configuration;
    }

    // Fall back: surface the raw Amplify message so we can debug unknown errors.
    safePrint('[AuthExceptionMapper] unmapped error — type=${error.runtimeTypeName} message="${error.message}"');
    return AuthFailure(error.message, code: error.runtimeTypeName);
  }
}
