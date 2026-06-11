import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_state.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/features/candidate/data/aws_application_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/application_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/user_profile_screen.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  testWidgets('profile manages skills inline and hides education section', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (_, _) => AuthState.authenticated(_candidateUser),
          ),
          applicationRepositoryProvider.overrideWithValue(
            _FakeApplicationRepository(),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: UserProfileScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Học vấn'), findsNothing);
    expect(find.text('Thêm học vấn của bạn'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Thêm kỹ năng của bạn'),
      500,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(find.text('Thêm kỹ năng của bạn'));
    await tester.pumpAndSettle();

    expect(find.text('Tìm hoặc tạo kỹ năng'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Pha chế');
    await tester.pump();

    expect(find.text('Thêm "Pha chế"'), findsOneWidget);
  });
}

const _candidateUser = AuthUserProfile(
  userId: 'candidate-1',
  username: 'candidate',
  role: AppRole.candidate,
  email: 'candidate@example.com',
  fullName: 'Nguyen An',
  kycCompleted: true,
  profileCompleted: true,
  skills: [],
);

class _FakeApplicationRepository implements ApplicationRepository {
  @override
  Future<void> confirmApplicationCompletion({
    required String applicationId,
    required DateTime confirmedAt,
  }) async {}

  @override
  Future<void> deleteCandidateCV({
    required String userId,
    String? cvId,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getCandidateApplications(
    String userId,
  ) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getCandidateCVs(String userId) async {
    return [];
  }

  @override
  Future<void> submitApplication({
    required String jobId,
    required String cvUrl,
    required String cvFilename,
    required ApplicationNotificationDetails notification,
  }) async {}

  @override
  Future<void> submitCandidateRating({
    required String applicationId,
    required Map<String, dynamic> candidateRating,
  }) async {}

  @override
  Future<void> updateApplicationChat({
    required String applicationId,
    required String status,
    required List<Map<String, dynamic>> chatMessages,
  }) async {}

  @override
  Future<Map<String, dynamic>> uploadCandidateCV({
    required String userId,
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
  }) async {
    return {'success': true};
  }
}
