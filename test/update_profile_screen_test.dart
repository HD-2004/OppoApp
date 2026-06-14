import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_state.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/update_profile_screen.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  testWidgets('update profile does not render social link section', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (_, _) => AuthState.authenticated(_candidate),
          ),
        ],
        child: const MaterialApp(home: UpdateProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Thông tin cá nhân'), findsOneWidget);
    expect(find.text('Thông tin công việc & kỹ năng'), findsOneWidget);
    expect(find.text('Lưu Thay Đổi'), findsOneWidget);

    expect(find.text('Liên kết mạng xã hội'), findsNothing);
    expect(find.text('Facebook URL'), findsNothing);
    expect(find.text('Instagram URL'), findsNothing);
    expect(find.text('Zalo'), findsNothing);
    expect(find.text('Website URL'), findsNothing);
  });
}

const _candidate = AuthUserProfile(
  userId: 'candidate-1',
  username: 'candidate',
  role: AppRole.candidate,
  email: 'candidate@example.com',
  fullName: 'Nguyen An',
  kycCompleted: true,
  profileCompleted: true,
  socialLinks: {
    'facebook': 'https://facebook.example/candidate',
    'instagram': 'https://instagram.example/candidate',
    'zalo': '0900000000',
    'website': 'https://candidate.example',
  },
);
