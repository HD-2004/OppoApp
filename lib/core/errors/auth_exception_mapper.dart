import 'package:amplify_flutter/amplify_flutter.dart';

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
    if (combined.contains('configuration') ||
        combined.contains('config') ||
        combined.contains('appclientid')) {
      return AuthFailure.configuration;
    }

    return AuthFailure(error.message, code: error.runtimeTypeName);
  }
}
