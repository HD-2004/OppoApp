import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/core/localization/app_localizations.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/data/user_profile_repository.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_state.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/presentation/user_jobs_screen.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  testWidgets('jobs screen controls do not overflow on mobile width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (_, _) => AuthState.authenticated(_candidateUser),
          ),
          activeJobsProvider.overrideWith((_) async => [_job]),
          activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: UserJobsScreen(showBackButton: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tìm thấy 1 công việc phù hợp'), findsOneWidget);
  });

  testWidgets('job type dropdown selects urgent jobs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (_, _) => AuthState.authenticated(_activeCandidateUser),
          ),
          activeJobsProvider.overrideWith((_) async => [_job, _secondJob]),
          activeQuickJobsProvider.overrideWith((_) async => [_quickJob]),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: UserJobsScreen(showBackButton: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Loại công việc'), findsOneWidget);
    expect(find.text('Công việc'), findsOneWidget);
    expect(find.text('Tìm thấy 2 công việc phù hợp'), findsOneWidget);

    await tester.tap(find.text('Loại công việc'));
    await tester.pumpAndSettle();

    expect(find.text('Công việc Tuyển gấp'), findsOneWidget);

    await tester.tap(find.text('Công việc Tuyển gấp'));
    await tester.pumpAndSettle();

    expect(find.text('Tìm thấy 1 công việc phù hợp'), findsOneWidget);
  });

  testWidgets('job type selector and saved jobs icon fit on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (_, _) => AuthState.authenticated(_activeCandidateWithSavedJobs),
          ),
          activeJobsProvider.overrideWith((_) async => [_job, _secondJob]),
          activeQuickJobsProvider.overrideWith((_) async => [_quickJob]),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: UserJobsScreen(showBackButton: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final horizontalScrollViews = tester
        .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
        .where((widget) => widget.scrollDirection == Axis.horizontal);

    expect(horizontalScrollViews, isEmpty);
    expect(find.text('Loại công việc'), findsOneWidget);
    expect(find.text('Công việc tiêu chuẩn'), findsOneWidget);
    expect(find.byKey(const Key('saved-jobs-button')), findsOneWidget);
    expect(find.byKey(const Key('saved-jobs-badge')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('saved-jobs-button')));
    await tester.pumpAndSettle();

    expect(find.text('Tìm thấy 2 công việc phù hợp'), findsOneWidget);
  });

  testWidgets('saved jobs badge ignores expired saved job ids', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (_, _) => AuthState.authenticated(_candidateWithExpiredSavedJob),
          ),
          userProfileRepositoryProvider.overrideWithValue(
            _FakeUserProfileRepository(),
          ),
          activeJobsProvider.overrideWith((_) async => [_job]),
          activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: UserJobsScreen(showBackButton: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('saved-jobs-button')), findsOneWidget);
    expect(find.byKey(const Key('saved-jobs-badge')), findsNothing);
    expect(find.text('1'), findsNothing);
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
);

const _activeCandidateUser = AuthUserProfile(
  userId: 'candidate-1',
  username: 'candidate',
  role: AppRole.candidate,
  email: 'candidate@example.com',
  fullName: 'Nguyen An',
  kycCompleted: true,
  profileCompleted: true,
  verificationStatus: 'APPROVED',
  isActive: true,
  latitude: 10.0,
  longitude: 106.0,
);

const _activeCandidateWithSavedJobs = AuthUserProfile(
  userId: 'candidate-1',
  username: 'candidate',
  role: AppRole.candidate,
  email: 'candidate@example.com',
  fullName: 'Nguyen An',
  kycCompleted: true,
  profileCompleted: true,
  verificationStatus: 'APPROVED',
  isActive: true,
  latitude: 10.0,
  longitude: 106.0,
  savedJobs: ['job-1', 'quick-job'],
);

const _candidateWithExpiredSavedJob = AuthUserProfile(
  userId: 'candidate-1',
  username: 'candidate',
  role: AppRole.candidate,
  email: 'candidate@example.com',
  fullName: 'Nguyen An',
  kycCompleted: true,
  profileCompleted: true,
  savedJobs: ['expired-job'],
);

final _job = JobPost(
  id: 'job-1',
  idJob: 'job-1',
  employerId: 'employer-1',
  employerName: 'Oppo Coffee',
  title: 'Nhân viên phục vụ',
  jobType: JobPostType.partTime,
  location: 'Quận 1, TP.HCM',
  salary: '30.000đ/giờ',
  shiftTime: '08:00 - 12:00',
  description: 'Phục vụ khách hàng tại quầy.',
  tags: const ['F&B'],
  postedAt: DateTime(2026),
);

final _secondJob = JobPost(
  id: 'job-2',
  idJob: 'job-2',
  employerId: 'employer-2',
  employerName: 'Oppo Bistro',
  title: 'Thu ngân',
  jobType: JobPostType.partTime,
  location: 'TP.HCM',
  salary: '35.000đ/giờ',
  shiftTime: '13:00 - 17:00',
  description: 'Hỗ trợ thanh toán tại quầy.',
  tags: const ['Retail'],
  postedAt: DateTime(2026, 1, 2),
);

final _quickJob = JobPost(
  id: 'quick-job',
  idJob: 'quick-job',
  employerId: 'employer-3',
  employerName: 'Oppo Mart',
  title: 'Phụ ca gấp',
  jobType: JobPostType.urgent,
  location: 'TP.HCM',
  latitude: 10.0,
  longitude: 106.0,
  salary: '40.000đ/giờ',
  shiftTime: '18:00 - 22:00',
  description: 'Phụ ca trong ngày.',
  tags: const ['Tuyển gấp'],
  postedAt: DateTime(2026, 1, 3),
  isQuickJob: true,
);

class _FakeUserProfileRepository implements UserProfileRepository {
  @override
  Future<void> savePendingRegistration(PendingRegistrationProfile profile) {
    throw UnimplementedError();
  }

  @override
  Future<AuthUserProfile?> getByUserId(String userId) {
    throw UnimplementedError();
  }

  @override
  Future<AuthUserProfile?> getByEmail(String email) {
    throw UnimplementedError();
  }

  @override
  Future<AuthUserProfile> upsertAfterLogin({
    required String userId,
    required String username,
    required String email,
    required String fullName,
    required AppRole? role,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthUserProfile> updateKycCompleted({
    required String userId,
    required bool completed,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthUserProfile> updateProfileCompleted({
    required String userId,
    required bool completed,
    String? fullName,
    String? phone,
    String? cccd,
    String? dateOfBirth,
    String? location,
    String? title,
    String? bio,
    List<String>? skills,
    String? profileImage,
    Map<String, String>? socialLinks,
    List<String>? savedJobs,
  }) async {
    return _candidateWithExpiredSavedJob.copyWith(savedJobs: savedJobs);
  }

  @override
  Future<AuthUserProfile> submitVerificationRequest({required String userId}) {
    throw UnimplementedError();
  }

  @override
  Future<AuthUserProfile> updateAvailability({
    required String userId,
    required bool isActive,
    double? latitude,
    double? longitude,
  }) {
    throw UnimplementedError();
  }
}
