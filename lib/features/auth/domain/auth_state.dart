import 'auth_user_profile.dart';

enum AuthStatus { unauthenticated, authenticated, unconfirmed, missingRole }

class AuthState {
  const AuthState._({required this.status, this.user, this.pendingEmail});

  const AuthState.unauthenticated()
    : this._(status: AuthStatus.unauthenticated);

  const AuthState.authenticated(AuthUserProfile user)
    : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.unconfirmed(String email)
    : this._(status: AuthStatus.unconfirmed, pendingEmail: email);

  const AuthState.missingRole(AuthUserProfile user)
    : this._(status: AuthStatus.missingRole, user: user);

  final AuthStatus status;
  final AuthUserProfile? user;
  final String? pendingEmail;
}
