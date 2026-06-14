import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/core/services/location_service.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_state.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/user_jobs_screen.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

class SpyAuthController extends AuthController {
  SpyAuthController(this.initialUser);

  final AuthUserProfile initialUser;
  bool? lastIsActive;
  double? lastLatitude;
  double? lastLongitude;
  int updateCount = 0;

  @override
  Future<AuthState> build() async {
    return AuthState.authenticated(initialUser);
  }

  @override
  Future<void> updateAvailability(
    bool isActive, {
    double? latitude,
    double? longitude,
  }) async {
    lastIsActive = isActive;
    lastLatitude = latitude;
    lastLongitude = longitude;
    updateCount++;

    final current = state.asData?.value.user;
    if (current != null) {
      final resolved = current.copyWith(
        isActive: isActive,
        latitude: latitude ?? current.latitude,
        longitude: longitude ?? current.longitude,
      );
      state = AsyncData(AuthState.authenticated(resolved));
    }
  }
}

void main() {
  setUp(() {
    LocationService.mockLocationProvider = null;
  });

  tearDown(() {
    LocationService.mockLocationProvider = null;
  });

  Widget buildTestWidget({
    required AuthUserProfile user,
    required SpyAuthController spyController,
  }) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => spyController),
        activeJobsProvider.overrideWith((_) async => <JobPost>[]),
        activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
        ],
        locale: Locale('vi'),
        home: Scaffold(
          body: UserJobsScreen(showBackButton: false),
        ),
      ),
    );
  }

  testWidgets(
    'calls updateAvailability with coordinates if no saved coordinates exist',
    (tester) async {
      final userWithoutCoords = const AuthUserProfile(
        userId: 'candidate-1',
        username: 'candidate',
        role: AppRole.candidate,
        email: 'candidate@example.com',
        fullName: 'Nguyen An',
        kycCompleted: true,
        profileCompleted: true,
        verificationStatus: 'APPROVED',
        isActive: false,
      );

      final spyController = SpyAuthController(userWithoutCoords);
      LocationService.mockLocationProvider = () async => (10.0, 106.0);

      await tester.pumpWidget(
        buildTestWidget(user: userWithoutCoords, spyController: spyController),
      );
      await tester.pumpAndSettle();

      // Go to tab 1 (Tuyển gấp)
      await tester.tap(find.text('Công việc Tuyển gấp'));
      await tester.pumpAndSettle();

      // Toggle switch to true
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(spyController.updateCount, 1);
      expect(spyController.lastIsActive, true);
      expect(spyController.lastLatitude, 10.0);
      expect(spyController.lastLongitude, 106.0);
    },
  );

  testWidgets(
    'calls updateAvailability with null coordinates if GPS shift is < 100 meters',
    (tester) async {
      final userWithCoords = const AuthUserProfile(
        userId: 'candidate-1',
        username: 'candidate',
        role: AppRole.candidate,
        email: 'candidate@example.com',
        fullName: 'Nguyen An',
        kycCompleted: true,
        profileCompleted: true,
        verificationStatus: 'APPROVED',
        isActive: false,
        latitude: 10.0,
        longitude: 106.0,
      );

      final spyController = SpyAuthController(userWithCoords);
      // 10.0001, 106.0001 is roughly 15 meters away from 10.0, 106.0
      LocationService.mockLocationProvider = () async => (10.0001, 106.0001);

      await tester.pumpWidget(
        buildTestWidget(user: userWithCoords, spyController: spyController),
      );
      await tester.pumpAndSettle();

      // Go to tab 1 (Tuyển gấp)
      await tester.tap(find.text('Công việc Tuyển gấp'));
      await tester.pumpAndSettle();

      // Toggle switch to true
      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(spyController.updateCount, 1);
      expect(spyController.lastIsActive, true);
      expect(spyController.lastLatitude, isNull);
      expect(spyController.lastLongitude, isNull);
    },
  );

  testWidgets(
    'calls updateAvailability with coordinates if GPS shift is >= 100 meters',
    (tester) async {
      final userWithCoords = const AuthUserProfile(
        userId: 'candidate-1',
        username: 'candidate',
        role: AppRole.candidate,
        email: 'candidate@example.com',
        fullName: 'Nguyen An',
        kycCompleted: true,
        profileCompleted: true,
        verificationStatus: 'APPROVED',
        isActive: false,
        latitude: 10.0,
        longitude: 106.0,
      );

      final spyController = SpyAuthController(userWithCoords);
      // 10.01, 106.01 is roughly 1.5 km away from 10.0, 106.0
      LocationService.mockLocationProvider = () async => (10.01, 106.01);

      await tester.pumpWidget(
        buildTestWidget(user: userWithCoords, spyController: spyController),
      );
      await tester.pumpAndSettle();

      // Go to tab 1 (Tuyển gấp)
      await tester.tap(find.text('Công việc Tuyển gấp'));
      await tester.pumpAndSettle();

      // Toggle switch to true
      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(spyController.updateCount, 1);
      expect(spyController.lastIsActive, true);
      expect(spyController.lastLatitude, 10.01);
      expect(spyController.lastLongitude, 106.01);
    },
  );
}
