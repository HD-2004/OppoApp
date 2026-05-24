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
}
