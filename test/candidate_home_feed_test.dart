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
import 'package:oppo_temp_jobs/features/candidate/presentation/widgets/candidate_intent_input.dart';
import 'package:oppo_temp_jobs/features/home/presentation/pages/candidate_home_page.dart';
import 'package:oppo_temp_jobs/features/home/presentation/widgets/home_s3_banner_carousel.dart';
import 'package:oppo_temp_jobs/features/messaging/application/messaging_providers.dart';
import 'package:oppo_temp_jobs/features/messaging/domain/candidate_application.dart';
import 'package:oppo_temp_jobs/shared/domain/app_role.dart';

void main() {
  testWidgets('candidate home uses a light app background', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (_, _) => AuthState.authenticated(_candidateUser),
          ),
          activeJobsProvider.overrideWith((_) async => [_job]),
          activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
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

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, Colors.white);
    expect(find.text('Ốp Pờ'), findsOneWidget);
    expect(find.text('Tìm việc, quán cà phê, nhà hàng...'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_rounded), findsNothing);
    expect(find.byIcon(Icons.notifications_rounded), findsNothing);
    expect(find.text('Bạn muốn tìm công việc như thế nào?'), findsOneWidget);
    expect(find.text('Đỗ ơi, bạn đang nghĩ gì thế?'), findsNothing);
    expect(find.byIcon(Icons.videocam_rounded), findsNothing);
    expect(find.byIcon(Icons.collections_rounded), findsNothing);
    expect(find.byIcon(Icons.movie_creation_rounded), findsNothing);
    expect(find.text('Tạo tin'), findsNothing);
    expect(find.text('Tin tuyển dụng nổi bật'), findsNothing);
    expect(find.textContaining('Nhân viên phục vụ'), findsOneWidget);
    expect(find.text('Ứng tuyển ngay'), findsOneWidget);
    expect(find.text('Nhiều ứng viên đang quan tâm'), findsNothing);
    expect(find.byIcon(Icons.thumb_up_rounded), findsNothing);
    expect(find.byIcon(Icons.more_horiz_rounded), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets(
    'candidate home shows a banner carousel between intent and feed',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWithBuild(
              (_, _) => AuthState.authenticated(_candidateUser),
            ),
            activeJobsProvider.overrideWith((_) async => [_job]),
            activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
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

      final intentTop = tester.getTopLeft(find.byType(CandidateIntentInput)).dy;
      final carouselTop = tester
          .getTopLeft(find.byType(HomeS3BannerCarousel))
          .dy;
      final feedHeaderTop = tester
          .getTopLeft(find.text('Bảng tin việc làm'))
          .dy;

      expect(find.byType(HomeS3BannerCarousel), findsOneWidget);
      expect(carouselTop, greaterThan(intentTop));
      expect(carouselTop, lessThan(feedHeaderTop));
    },
  );

  testWidgets('candidate home shows featured jobs from backend visibility', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWithBuild(
            (_, _) => AuthState.authenticated(_candidateUser),
          ),
          activeJobsProvider.overrideWith((_) async => [_featuredJob]),
          activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
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

    expect(find.text('Tin tuyển dụng nổi bật'), findsOneWidget);
    expect(find.text('Xem tất cả'), findsWidgets);
    expect(find.text('Nổi bật'), findsOneWidget);
    expect(find.text('Barista cuối tuần'), findsWidgets);
    expect(find.text('Oppo Coffee'), findsWidgets);
    expect(find.text('Tạo tin'), findsNothing);
  });
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
  employerName: 'Nhật Bản Hóng',
  title: 'Nhân viên phục vụ',
  jobType: JobPostType.partTime,
  location: 'Quận 1, TP.HCM',
  salary: '35.000đ/giờ',
  shiftTime: '18:00 - 23:00',
  description: 'Chính thức các nàng thơ ban đêm đi hái mận nhà hàng xóm.',
  tags: const ['Ca tối', 'F&B'],
  postedAt: DateTime(2026),
);

final _featuredJob = JobPost(
  id: 'job-featured-1',
  idJob: 'job-featured-1',
  employerId: 'employer-featured-1',
  employerName: 'Oppo Coffee',
  title: 'Barista cuối tuần',
  jobType: JobPostType.partTime,
  location: 'Thủ Đức',
  salary: '40.000đ/giờ',
  shiftTime: '08:00 - 13:00',
  description: 'Tuyển barista cuối tuần.',
  tags: const ['F&B'],
  postedAt: DateTime(2026, 6, 2),
  visibilityScore: 4,
);
