class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;

  static const configuration = AuthFailure(
    'Cognito chưa được cấu hình đúng. Hãy kiểm tra Region, User Pool ID và App Client ID.',
    code: 'configuration',
  );

  static const socialSignInConfiguration = AuthFailure(
    'Đăng nhập Google/Facebook chưa được cấu hình trên Cognito Hosted UI. Hãy kiểm tra domain, callback URL và social provider trong Cognito.',
    code: 'social_sign_in_configuration',
  );
}
