import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
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
        child: const MaterialApp(home: UserJobsScreen(showBackButton: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tìm thấy 1 công việc phù hợp'), findsOneWidget);
  });

  testWidgets('urgent tab badge shows urgent count before tab is selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (_, _) => AuthState.authenticated(_activeCandidateUser),
          ),
          activeJobsProvider.overrideWith((_) async => [_job, _secondJob]),
          activeQuickJobsProvider.overrideWith((_) async => [_quickJob]),
        ],
        child: const MaterialApp(home: UserJobsScreen(showBackButton: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Công việc tiêu chuẩn'), findsOneWidget);
    expect(find.text('Công việc Tuyển gấp'), findsOneWidget);
    expect(find.text('Tìm thấy 2 công việc phù hợp'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
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
