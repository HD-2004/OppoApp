import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  test('authenticated mobile users always route to candidate home', () {
    final controller = AuthController();

    expect(
      controller.routeAfterLogin(_profile(AppRole.candidate)),
      '/candidate',
    );
    expect(controller.routeAfterLogin(_profile(null)), '/candidate');
  });
}

AuthUserProfile _profile(AppRole? role) {
  return AuthUserProfile(
    userId: 'user-1',
    username: 'candidate@example.com',
    role: role,
    email: 'candidate@example.com',
    fullName: 'Candidate',
    kycCompleted: false,
    profileCompleted: false,
  );
}
