import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/auth/application/auth_controller.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_state.dart';
import 'package:oppo_temp_jobs/features/auth/domain/auth_user_profile.dart';
import 'package:oppo_temp_jobs/features/candidate/data/aws_application_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/application_repository.dart';
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
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  testWidgets('candidate home renders marketplace sections from providers', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      standardJobs: [_job, _sameEmployerJob],
      banners: const [_firstBanner],
      applications: _recentApplications,
    );

    expect(find.text('Ốp Pờ'), findsOneWidget);
    expect(find.textContaining('Đỗ Nhật'), findsOneWidget);
    expect(find.text('Tìm việc, công ty, bài đăng...'), findsNothing);
    expect(find.text('Nơi Tìm Việc Linh Hoạt'), findsNothing);
    expect(find.text('Công việc phổ biến nhất'), findsOneWidget);
    expect(find.text('Việc hợp bạn nhất'), findsNothing);
    expect(find.text('Đơn Ứng Tuyển Của Bạn Gần Đây'), findsOneWidget);
    expect(
      find.text('Top công ty đang tuyển nhiều fresher nhất'),
      findsNothing,
    );
    expect(find.text('Thu ngân quán'), findsOneWidget);
    expect(find.text('Katinat Quận Cam'), findsOneWidget);
    expect(find.text('Chưa Xem'), findsNWidgets(2));
    expect(find.text('Tiêu Chuẩn'), findsNWidgets(2));
    expect(find.text('Xem chi tiết'), findsNWidgets(2));
    expect(find.text('Việc hợp hướng đi'), findsNothing);
    expect(find.text('Nhân viên phục vụ'), findsWidgets);
    expect(find.text('Featured Cafe'), findsNothing);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.byIcon(Icons.share_rounded), findsNothing);
    expect(find.byIcon(Icons.comment_rounded), findsNothing);
  });

  testWidgets('candidate can open job detail from recent applications', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      standardJobs: [_job, _sameEmployerJob],
      banners: const [],
      applications: _recentApplications,
    );

    await tester.tap(find.text('Thu ngân quán'));
    await tester.pumpAndSettle();

    expect(find.text('Thông tin nhà tuyển dụng'), findsOneWidget);
    expect(find.text('Nhân viên phục vụ'), findsWidgets);
    expect(find.text('Oppo Coffee'), findsWidgets);
    expect(find.text('Quận 1, TP.HCM'), findsOneWidget);
  });

  testWidgets('candidate home shows popular jobs from active job data', (
    tester,
  ) async {
    await _pumpHome(tester, standardJobs: [_job], banners: const []);

    expect(find.text('Công việc phổ biến nhất'), findsOneWidget);
    expect(find.text('Nhân viên phục vụ'), findsOneWidget);
  });

  testWidgets('candidate home ranks popular jobs by submitted CV count', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpHome(
      tester,
      standardJobs: [_job, _sameEmployerJob],
      banners: const [],
      preserveSurfaceSize: true,
    );

    final popularTitle = find.text('Barista cuối tuần').first;
    final lowerTitle = find.text('Nhân viên phục vụ').first;

    expect(
      tester.getTopLeft(popularTitle).dx,
      lessThan(tester.getTopLeft(lowerTitle).dx),
    );
  });

  testWidgets(
    'candidate home keeps empty sections stable when APIs return empty lists',
    (tester) async {
      await _pumpHome(tester, standardJobs: const [], banners: const []);

      expect(find.text('Chưa có bài đăng tuyển dụng mới.'), findsNothing);
      expect(find.text('Việc hợp hướng đi'), findsNothing);
      expect(find.text('Chưa có việc để hiển thị.'), findsNothing);
      expect(find.text('Tạm thời chưa có công việc phổ biến.'), findsOneWidget);
      expect(find.text('Đơn Ứng Tuyển Của Bạn Gần Đây'), findsNothing);
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
    expect(find.text('Đề xuất'), findsNothing);
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

  testWidgets('sponsored employer banner hides incorrectly sized banners', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SponsoredBannerSection(
            banners: const [_firstBanner, _wrongSizeBanner],
            isLoading: false,
          ),
        ),
      ),
    );

    await tester.pump();

    expect(
      find.byKey(const Key('featured-employer-banner-slide-view')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('featured-employer-banner-dots')),
      findsNothing,
    );
  });

  testWidgets('popular job card shows compact schedule line', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 430,
              width: 328,
              child: JobCard(job: _multiShiftJob, onTap: () {}, onApply: () {}),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text('Thời gian: 06:30 - 11:00 | 08:00 - 11:30 | 13:00 - 17:00'),
      findsOneWidget,
    );
    expect(find.text('Ngày làm: T2 | T5 | T7'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    expect(find.text('Hạn nộp: 12/07/2026'), findsOneWidget);
    expect(find.text('Xem thêm...'), findsNothing);
    expect(find.text('Thu gọn'), findsNothing);
  });

  testWidgets('popular job card hides undisclosed schedule placeholder', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 430,
              width: 328,
              child: JobCard(job: _shiftOnlyJob, onTap: () {}, onApply: () {}),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Không công khai'), findsNothing);
    expect(find.text('Thời gian: 07:00 - 12:00'), findsOneWidget);
  });

  testWidgets('popular job card keeps salary close to company name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 430,
              width: 328,
              child: JobCard(
                job: _compactRecommendedJob,
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
    final salaryTop = tester
        .getTopLeft(find.text('Thu nhập: 468 VNĐ/0 giờ'))
        .dy;

    expect(tester.takeException(), isNull);
    expect(salaryTop - companyBottom, lessThan(96));
  });

  testWidgets('popular job card uses compact reference layout with S3 logo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              height: 430,
              width: 328,
              child: JobCard(
                job: _referenceCardJob,
                onTap: () {},
                onApply: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('THU NGÂN QUÁN'), findsOneWidget);
    expect(find.text('Katinat Quận Cam'), findsOneWidget);
    expect(find.text('Tiêu chuẩn'), findsOneWidget);
    expect(find.text('Quận 2'), findsOneWidget);
    expect(find.text('Part-time'), findsOneWidget);
    expect(find.text('43 lượt xem'), findsOneWidget);
    expect(find.text('Thu ngân'), findsOneWidget);
    expect(find.text('F&B'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Thu nhập: 25.000 VNĐ/giờ'), findsOneWidget);
    expect(
      find.text('Thời gian: 07:00 - 12:00 | 12:00 - 17:30'),
      findsOneWidget,
    );
    expect(find.text('Hạn nộp: 11/07/2026'), findsOneWidget);
    expect(find.text('Vị trí này có thể phù hợp với bạn'), findsOneWidget);

    final logoImage = tester.widget<Image>(find.byType(Image).first);
    expect(
      (logoImage.image as NetworkImage).url,
      'https://opporeview-cv-storage.s3.ap-southeast-1.amazonaws.com/system/katinatlogo.jpg',
    );
  });

  testWidgets('popular jobs section keeps cards visible while refreshing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PopularJobsSection(
            jobs: [_job],
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
    expect(find.textContaining('Phù hợp:'), findsNothing);
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required List<JobPost> standardJobs,
  required List<BannerAd> banners,
  List<Map<String, dynamic>> applications = const [],
  bool preserveSurfaceSize = false,
}) async {
  if (!preserveSurfaceSize) {
    await tester.binding.setSurfaceSize(const Size(430, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWithBuild(
          (_, _) => AuthState.authenticated(_candidateUser),
        ),
        activeJobsProvider.overrideWith((_) async => standardJobs),
        activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
        bannersProvider.overrideWith((_) async => banners),
        applicationRepositoryProvider.overrideWith(
          (_) => _FakeApplicationRepository(applications),
        ),
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
  imageWidth: 1600,
  imageHeight: 517,
);

const _secondBanner = BannerAd(
  bannerId: 'banner-2',
  title: 'Second Bistro',
  imageUrl: 'https://example.com/banner-2.jpg',
  imageWidth: 1600,
  imageHeight: 517,
);

const _wrongSizeBanner = BannerAd(
  bannerId: 'wrong-banner',
  title: 'Wrong size',
  imageUrl: 'https://example.com/wrong-banner.jpg',
  imageWidth: 720,
  imageHeight: 1280,
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
  applicants: 2,
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
  applicants: 12,
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

final _referenceCardJob = JobPost(
  id: 'job-reference',
  idJob: 'job-reference',
  employerId: 'employer-1',
  employerName: 'Katinat Quận Cam',
  title: 'THU NGÂN QUÁN',
  jobType: JobPostType.partTime,
  location: 'Quận 2',
  salary: '25.000 VNĐ/giờ',
  shiftTime: '07:00 - 12:00 | 12:00 - 17:30',
  description: 'Thu ngân tại quán.',
  tags: const ['Thu ngân', 'F&B', 'Coffee'],
  postedAt: DateTime(2026, 7, 1),
  recruitmentEndDate: DateTime(2026, 7, 11),
  views: 43,
);

const _recentApplications = [
  {
    'applicationId': 'app-1',
    'jobId': 'job-1',
    'jobTitle': 'Thu ngân quán',
    'jobType': 'standard',
    'candidateId': 'candidate-1',
    'candidateEmail': 'candidate@example.com',
    'employerId': 'employer-1',
    'employerEmail': 'hr@katinat.vn',
    'employerName': 'Katinat Quận Cam',
    'status': 'submitted',
    'appliedAt': '2026-07-12T10:00:00Z',
    'updatedAt': '2026-07-12T10:00:00Z',
  },
  {
    'applicationId': 'app-2',
    'jobId': 'job-2',
    'jobTitle': 'Nhân viên Cửa hàng',
    'jobType': 'standard',
    'candidateId': 'candidate-1',
    'candidateEmail': 'candidate@example.com',
    'employerId': 'employer-2',
    'employerEmail': 'hr@bamos.vn',
    'employerName': 'CÔNG TY TNHH SẢN XUẤT THƯƠNG MẠI DỊCH VỤ BAMOS',
    'status': 'submitted',
    'appliedAt': '2026-07-10T10:00:00Z',
    'updatedAt': '2026-07-10T10:00:00Z',
  },
];

class _FakeApplicationRepository implements ApplicationRepository {
  const _FakeApplicationRepository(this.applications);

  final List<Map<String, dynamic>> applications;

  @override
  Future<List<Map<String, dynamic>>> getCandidateApplications(String userId) {
    return Future.value(applications);
  }

  @override
  Future<List<Map<String, dynamic>>> getCandidateCVs(String userId) {
    return Future.value(const []);
  }

  @override
  Future<Map<String, dynamic>> submitApplication({
    required String jobId,
    required String cvUrl,
    required String cvFilename,
    required ApplicationNotificationDetails notification,
    String? cvS3Key,
    Map<String, dynamic>? extraFields,
  }) {
    return Future.value(<String, dynamic>{});
  }

  @override
  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
    Map<String, dynamic> extraFields = const {},
  }) async {}

  @override
  Future<Map<String, dynamic>> uploadCandidateCV({
    required String userId,
    required List<int> fileBytes,
    required String fileName,
    required String fileType,
  }) {
    return Future.value(<String, dynamic>{});
  }

  @override
  Future<void> deleteCandidateCV({
    required String userId,
    String? cvId,
  }) async {}

  @override
  Future<void> confirmApplicationCompletion({
    required String applicationId,
    required DateTime confirmedAt,
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
  Future<void> archiveApplicationChat({
    required String applicationId,
    required DateTime archivedAt,
  }) async {}

  @override
  Future<void> sendCandidateAiScreeningPassedNotification({
    required String candidateId,
    required String jobTitle,
    required String companyName,
    required String jobId,
    required int score,
  }) async {}

  @override
  Future<void> sendCandidateAiScreeningRejectedNotification({
    required String candidateId,
    required String jobTitle,
    required String companyName,
    required String jobId,
  }) async {}

  @override
  Future<void> sendEmployerApplicationNotification({
    required String jobId,
    required ApplicationNotificationDetails details,
  }) async {}
}
