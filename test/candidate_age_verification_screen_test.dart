import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_state.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/features/auth/domain/candidate_age_policy.dart';
import 'package:oppo_temp_jobs/features/auth/presentation/candidate_age_verification_screen.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  testWidgets('saves eligible date of birth', (tester) async {
    final spyController = _SpyAuthController();
    await tester.pumpWidget(_appWithController(spyController));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ngày sinh'),
      '05/01/2000',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
    await tester.pumpAndSettle();

    expect(spyController.completedDateOfBirth, '2000-01-05');
    expect(spyController.signOutCount, 0);
  });

  testWidgets('signs out candidates under 18', (tester) async {
    final spyController = _SpyAuthController();
    await tester.pumpWidget(_appWithController(spyController));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ngày sinh'),
      _underageDateOfBirth(),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Tiếp tục'));
    await tester.pumpAndSettle();

    expect(
      find.text('Ứng dụng chỉ dành cho ứng viên từ 18 tuổi trở lên.'),
      findsOneWidget,
    );
    expect(spyController.signOutCount, 1);
    expect(spyController.completedDateOfBirth, isNull);
  });
}

String _underageDateOfBirth() {
  final today = DateTime.now();
  final eighteenthBirthdayTomorrow = DateTime(
    today.year - CandidateAgePolicy.minimumAge,
    today.month,
    today.day + 1,
  );
  return CandidateAgePolicy.formatDisplayDate(eighteenthBirthdayTomorrow);
}

Widget _appWithController(_SpyAuthController controller) {
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith(() => controller)],
    child: const MaterialApp(home: CandidateAgeVerificationScreen()),
  );
}

class _SpyAuthController extends AuthController {
  String? completedDateOfBirth;
  int signOutCount = 0;

  @override
  Future<AuthState> build() async {
    return AuthState.authenticated(_candidate);
  }

  @override
  Future<void> saveDateOfBirth(String dateOfBirth) async {
    completedDateOfBirth = dateOfBirth;
    state = AsyncData(
      AuthState.authenticated(_candidate.copyWith(dateOfBirth: dateOfBirth)),
    );
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    state = const AsyncData(AuthState.unauthenticated());
  }
}

const _candidate = AuthUserProfile(
  userId: 'candidate-1',
  username: 'candidate',
  role: AppRole.candidate,
  email: 'candidate@example.com',
  fullName: 'Nguyen An',
  kycCompleted: true,
  profileCompleted: true,
);
