import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/app/router.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_state.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  test('redirects authenticated candidate without DOB to age verification', () {
    final redirect = candidateAgeGateRedirect(
      AuthState.authenticated(_candidate(dateOfBirth: null)),
      '/candidate',
    );

    expect(redirect, '/candidate/age-verification');
  });

  test('does not redirect candidate who is already on age verification', () {
    final redirect = candidateAgeGateRedirect(
      AuthState.authenticated(_candidate(dateOfBirth: null)),
      '/candidate/age-verification',
    );

    expect(redirect, isNull);
  });

  test('redirects candidate with DOB away from age verification', () {
    final redirect = candidateAgeGateRedirect(
      AuthState.authenticated(_candidate(dateOfBirth: '2000-01-05')),
      '/candidate/age-verification',
    );

    expect(redirect, '/candidate');
  });
}

AuthUserProfile _candidate({required String? dateOfBirth}) {
  return AuthUserProfile(
    userId: 'candidate-1',
    username: 'candidate',
    role: AppRole.candidate,
    email: 'candidate@example.com',
    fullName: 'Nguyen An',
    kycCompleted: true,
    profileCompleted: true,
    dateOfBirth: dateOfBirth,
  );
}
