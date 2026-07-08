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
import 'package:oppo_temp_jobs/features/home/presentation/widgets/candidate_home_marketplace_sections.dart';
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
      banners: const [_firstBanner],
    );

    expect(find.text('Ốp Pờ'), findsOneWidget);
    expect(find.textContaining('Đỗ Nhật'), findsOneWidget);
    expect(find.text('Tìm việc, công ty, bài đăng...'), findsOneWidget);
    expect(find.text('Nơi Tìm Việc Linh Hoạt'), findsNothing);
    expect(find.text('Việc hợp bạn nhất'), findsOneWidget);
    expect(
      find.text('Top công ty đang tuyển nhiều fresher nhất'),
      findsOneWidget,
    );
    expect(find.text('Việc hợp hướng đi'), findsNothing);
    expect(find.text('Nhân viên phục vụ'), findsWidgets);
    expect(find.text('Featured Cafe'), findsNothing);
    expect(find.text('2 việc đang tuyển'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byIcon(Icons.share_rounded), findsNothing);
    expect(find.byIcon(Icons.comment_rounded), findsNothing);
  });

  testWidgets('candidate can open employer info from top companies', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      standardJobs: [_job, _sameEmployerJob],
      recommendations: const [],
      banners: const [],
    );

    await tester.tap(find.text('Oppo Coffee'));
    await tester.pumpAndSettle();

    expect(find.text('Thông tin nhà tuyển dụng'), findsOneWidget);
    expect(find.text('Oppo Coffee'), findsWidgets);
    expect(find.text('2 việc đang tuyển'), findsWidgets);
    expect(find.text('Nhân viên phục vụ'), findsOneWidget);
    expect(find.text('Barista cuối tuần'), findsOneWidget);
    expect(find.text('Quận 1, TP.HCM'), findsOneWidget);
    expect(find.text('Thủ Đức'), findsOneWidget);
    expect(find.text('Katinat Quận Cam'), findsNothing);
  });

  testWidgets(
    'candidate home shows recommendation empty state for empty API data',
    (tester) async {
      await _pumpHome(
        tester,
        standardJobs: [_job],
        recommendations: const [],
        banners: const [],
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
        banners: const [],
      );

      expect(find.text('Chưa có bài đăng tuyển dụng mới.'), findsNothing);
      expect(find.text('Việc hợp hướng đi'), findsNothing);
      expect(find.text('Chưa có việc để hiển thị.'), findsNothing);
      expect(
        find.text('Top công ty đang tuyển nhiều fresher nhất'),
        findsNothing,
      );
      expect(find.text('Featured Cafe'), findsNothing);
    },
  );

  testWidgets('sponsored employer banner automatically advances slides', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SponsoredBannerSection(
            banners: const [_firstBanner, _secondBanner],
            isLoading: false,
            autoSlideInterval: const Duration(milliseconds: 500),
            slideAnimationDuration: const Duration(milliseconds: 80),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Đề xuất'), findsWidgets);
    expect(
      find.byKey(const Key('featured-employer-banner-dots')),
      findsOneWidget,
    );
    final firstPageView = tester.widget<PageView>(
      find.byKey(const Key('featured-employer-banner-slide-view')),
    );
    expect(firstPageView.controller?.page, closeTo(0, 0.01));

    await tester.pump(const Duration(milliseconds: 501));
    await tester.pump(const Duration(milliseconds: 80));

    final secondPageView = tester.widget<PageView>(
      find.byKey(const Key('featured-employer-banner-slide-view')),
    );
    expect(secondPageView.controller?.page, closeTo(1, 0.01));
  });

  testWidgets('recommended job card expands work shifts inline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 352,
              width: 286,
              child: JobCard(
                job: _multiShiftJob,
                matchScore: 90,
                onTap: () {},
                onApply: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('T2 @ 06:30 - 11:00 | T5 @ 08:00 - 11:30'), findsNothing);
    expect(find.text('10/07/2026'), findsOneWidget);
    expect(find.text('Ca 1: 06:30 - 11:00'), findsOneWidget);
    expect(find.text('Ca 2: 08:00 - 11:30'), findsOneWidget);
    expect(find.text('Ca 3: 13:00 - 17:00'), findsNothing);
    expect(find.text('Xem thêm...'), findsOneWidget);

    await tester.tap(find.text('Xem thêm...'));
    await tester.pumpAndSettle();

    expect(find.text('Ca 3: 13:00 - 17:00'), findsOneWidget);
    expect(find.text('Thu gọn'), findsOneWidget);
  });

  testWidgets('recommended job card hides undisclosed schedule placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 352,
              width: 286,
              child: JobCard(
                job: _shiftOnlyJob,
                matchScore: 88,
                onTap: () {},
                onApply: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Không công khai'), findsNothing);
    expect(find.text('Ca 1: 07:00 - 12:00'), findsOneWidget);
  });

  testWidgets('recommended job card keeps salary close to company name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 352,
              width: 286,
              child: JobCard(
                job: _compactRecommendedJob,
                matchScore: 95,
                onTap: () {},
                onApply: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final companyBottom = tester
        .getBottomLeft(find.text('Katinat Quận Cam'))
        .dy;
    final salaryTop = tester.getTopLeft(find.text('468 VNĐ/0 giờ')).dy;

    expect(salaryTop - companyBottom, lessThan(48));
  });

  testWidgets('recommended jobs section keeps cards visible while refreshing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecommendedJobsSection(
            recommendations: [
              JobRecommendation(job: _job, matchScore: 72, reasons: const []),
            ],
            isLoading: true,
            hasError: false,
            onRetry: () {},
            onSeeAll: () {},
            onJobTap: (_) {},
            onApply: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Nhân viên phục vụ'), findsOneWidget);
    expect(find.text('Phù hợp: 72%'), findsOneWidget);
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<JobPost> standardJobs,
  required List<JobRecommendation> recommendations,
  required List<BannerAd> banners,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 2200));
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
        bannersProvider.overrideWith((_) async => banners),
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

const _firstBanner = BannerAd(
  bannerId: 'banner-1',
  title: 'First Cafe',
  imageUrl: 'https://example.com/banner-1.jpg',
);

const _secondBanner = BannerAd(
  bannerId: 'banner-2',
  title: 'Second Bistro',
  imageUrl: 'https://example.com/banner-2.jpg',
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

final _multiShiftJob = JobPost(
  id: 'job-3',
  idJob: 'job-3',
  employerId: 'employer-1',
  employerName: 'Katinat Quận Cam',
  title: 'Pha chế thức uống',
  jobType: JobPostType.partTime,
  location: 'Quận 2',
  salary: '6.000.000 VNĐ/giờ',
  shiftTime: 'T2 @ 06:30 - 11:00 | T5 @ 08:00 - 11:30 | T7 @ 13:00 - 17:00',
  description: 'Pha chế và chuẩn bị nguyên liệu.',
  tags: const ['F&B'],
  postedAt: DateTime(2026, 6, 12),
  recruitmentStartDate: DateTime(2026, 7, 10),
  recruitmentEndDate: DateTime(2026, 7, 12),
);

final _compactRecommendedJob = JobPost(
  id: 'quick-job-compact',
  idJob: 'quick-job-compact',
  employerId: 'employer-1',
  employerName: 'Katinat Quận Cam',
  title: 'Pha chế',
  jobType: JobPostType.urgent,
  location: 'Quận 2',
  salary: '468 VNĐ/0 giờ',
  shiftTime: '',
  description: 'Cần nhân viên pha chế gấp.',
  tags: const ['F&B'],
  postedAt: DateTime(2026, 7, 2),
  isQuickJob: true,
);

final _shiftOnlyJob = JobPost(
  id: 'job-shift-only',
  idJob: 'job-shift-only',
  employerId: 'employer-1',
  employerName: 'Katinat Quận Cam',
  title: 'Phụ ca sáng',
  jobType: JobPostType.partTime,
  location: 'Quận 2',
  salary: '30.000đ/giờ',
  shiftTime: '07:00 - 12:00',
  description: 'Phụ ca buổi sáng.',
  tags: const ['F&B'],
  postedAt: DateTime(2026, 7, 2),
);
