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
