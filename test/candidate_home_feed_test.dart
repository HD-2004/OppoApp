import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_state.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/application/notification_controller.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_repository.dart';
import 'package:oppo_temp_jobs/features/employer_packages/application/featured_employer_package_providers.dart';
import 'package:oppo_temp_jobs/features/employer_packages/domain/employer_package.dart';
import 'package:oppo_temp_jobs/features/home/presentation/pages/candidate_home_page.dart';
import 'package:oppo_temp_jobs/features/messaging/application/messaging_providers.dart';
import 'package:oppo_temp_jobs/features/messaging/domain/candidate_application.dart';
import 'package:oppo_temp_jobs/features/recommendations/application/job_recommendation_providers.dart';
import 'package:oppo_temp_jobs/features/recommendations/domain/job_recommendation.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  testWidgets('candidate home renders marketplace sections from providers', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      standardJobs: [_job, _sameEmployerJob],
      recommendations: [
        JobRecommendation(job: _job, matchScore: 72, reasons: const []),
      ],
      featuredEmployers: const [
        FeaturedEmployer(
          id: 'featured-1',
          name: 'Featured Cafe',
          packageTier: EmployerPackageTier.premium,
          activeJobCount: 3,
        ),
      ],
    );

    expect(find.text('Ốp Pờ'), findsOneWidget);
    expect(find.textContaining('Đỗ Nhật'), findsOneWidget);
    expect(find.text('Tìm việc, công ty, bài đăng...'), findsOneWidget);
    expect(find.text('Nơi Tìm Việc Linh Hoạt'), findsOneWidget);
    expect(find.text('Việc hợp bạn nhất'), findsOneWidget);
    expect(
      find.text('Top công ty đang tuyển nhiều fresher nhất'),
      findsOneWidget,
    );
    expect(find.text('Việc hợp hướng đi'), findsOneWidget);
    expect(find.text('Nhân viên phục vụ'), findsWidgets);
    expect(find.text('Featured Cafe'), findsOneWidget);
    expect(find.text('2 việc đang tuyển'), findsOneWidget);

    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byIcon(Icons.share_rounded), findsNothing);
    expect(find.byIcon(Icons.comment_rounded), findsNothing);
  });

  testWidgets(
    'candidate home shows recommendation empty state for empty API data',
    (tester) async {
      await _pumpHome(
        tester,
        standardJobs: [_job],
        recommendations: const [],
        featuredEmployers: const [],
      );

      expect(
        find.text(
          'Tạm thời chưa có việc phù hợp. Bạn cập nhật lại hồ sơ cá nhân để có gợi ý mới nha.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'candidate home keeps empty sections stable when APIs return empty lists',
    (tester) async {
      await _pumpHome(
        tester,
        standardJobs: const [],
        recommendations: const [],
        featuredEmployers: const [],
      );

      expect(find.text('Chưa có bài đăng tuyển dụng mới.'), findsOneWidget);
      expect(find.text('Việc hợp hướng đi'), findsOneWidget);
      expect(
        find.text('Top công ty đang tuyển nhiều fresher nhất'),
        findsNothing,
      );
      expect(find.text('Featured Cafe'), findsNothing);
    },
  );
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<JobPost> standardJobs,
  required List<JobRecommendation> recommendations,
  required List<FeaturedEmployer> featuredEmployers,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWithBuild(
          (_, _) => AuthState.authenticated(_candidateUser),
        ),
        activeJobsProvider.overrideWith((_) async => standardJobs),
        activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
        personalizedJobRecommendationsProvider.overrideWith(
          (_) async => recommendations,
        ),
        featuredEmployersProvider.overrideWith((_) async => featuredEmployers),
        candidateChatsProvider.overrideWithBuild(
          (_, _) => <CandidateApplication>[],
        ),
        candidateNotificationControllerProvider.overrideWithBuild(
          (_, _) => const CandidateNotificationList(
            items: [],
            summary: CandidateNotificationSummary(total: 0, unread: 0),
          ),
        ),
      ],
      child: MaterialApp(
        home: CandidateHomePage(
          onNotificationTap: () {},
          onSeeAllJobsTap: () {},
          onWalletTap: () {},
          onJobsTap: () {},
          onProfileTap: () {},
          onSettingsTap: () {},
          onSupportTap: () {},
          onSignOutTap: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _candidateUser = AuthUserProfile(
  userId: 'candidate-1',
  username: 'candidate',
  role: AppRole.candidate,
  email: 'candidate@example.com',
  fullName: 'Đỗ Nhật',
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
  salary: '35.000đ/giờ',
  shiftTime: '18:00 - 23:00',
  description: 'Tuyển nhân viên phục vụ ca tối.',
  tags: const ['Ca tối', 'F&B'],
  postedAt: DateTime(2026, 6, 10),
);

final _sameEmployerJob = JobPost(
  id: 'job-2',
  idJob: 'job-2',
  employerId: 'employer-1',
  employerName: 'Oppo Coffee',
  title: 'Barista cuối tuần',
  jobType: JobPostType.partTime,
  location: 'Thủ Đức',
  salary: '40.000đ/giờ',
  shiftTime: '08:00 - 13:00',
  description: 'Cần bạn phụ pha chế cuối tuần.',
  tags: const ['F&B'],
  postedAt: DateTime(2026, 6, 2),
);
