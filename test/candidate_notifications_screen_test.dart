import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/application/notification_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/application/jobs_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/domain/job_post.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/candidate_notification.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_status.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_type.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/presentation/candidate_notifications_screen.dart';

void main() {
  testWidgets('opens notification detail when a notification is tapped', (
    tester,
  ) async {
    final notification = CandidateNotification(
      id: 'n1',
      type: CandidateNotificationType.cvAccepted,
      title: 'CV của bạn đã được chấp nhận',
      body: 'CV của bạn đã được Katinat chấp nhận cho vị trí thu ngân.',
      status: CandidateNotificationStatus.unread,
      createdAt: DateTime.parse('2026-07-06T10:00:00Z'),
      entityType: 'APPLICATION',
      entityId: 'app1',
      deepLink: '/candidate/applications/app1',
      data: const {
        'companyName': 'Katinat Quận Cam',
        'candidateName': 'Nguyễn An',
        'jobId': 'JOB-20260708-NU2ZU',
        'employerId': 'f99a05cc-3011-7065-81ee-c97772e7629c',
        'stage': 'employer_accepted',
      },
    );
    final repository = _FakeNotificationRepository(
      CandidateNotificationList(
        items: [notification],
        summary: const CandidateNotificationSummary(total: 1, unread: 1),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          candidateNotificationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: CandidateNotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CV của bạn đã được chấp nhận'));
    await tester.pumpAndSettle();

    expect(repository.readIds, ['n1']);
    expect(find.text('Chi tiết thông báo'), findsOneWidget);
    expect(
      find.text('CV của bạn đã được Katinat chấp nhận cho vị trí thu ngân.'),
      findsOneWidget,
    );
    expect(find.text('Người gửi'), findsOneWidget);
    expect(find.text('Katinat Quận Cam'), findsOneWidget);
    expect(find.text('Người nhận'), findsOneWidget);
    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.text('Ngày'), findsOneWidget);
    expect(find.text('06/07/2026'), findsOneWidget);
    expect(find.text('10:00, 06/07/2026'), findsNothing);
    expect(find.text('Mã công việc'), findsNothing);
    expect(find.text('JOB-20260708-NU2ZU'), findsNothing);
    expect(find.text('employerId'), findsNothing);
    expect(find.text('f99a05cc-3011-7065-81ee-c97772e7629c'), findsNothing);
    expect(find.text('stage'), findsNothing);
    expect(find.text('employer_accepted'), findsNothing);

    final toneIndicator = tester.widget<Container>(
      find.byKey(const Key('notification-tone-indicator')),
    );
    final decoration = toneIndicator.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFEAF7EE));
  });

  testWidgets('rejected notification detail uses red tone', (tester) async {
    final notification = CandidateNotification(
      id: 'n2',
      type: CandidateNotificationType.cvRejected,
      title: 'Hồ sơ chưa được duyệt',
      body: 'Rất tiếc, hồ sơ của bạn chưa phù hợp.',
      status: CandidateNotificationStatus.read,
      createdAt: DateTime.parse('2026-07-08T14:25:00Z'),
      data: const {
        'employerName': 'Nhà tuyển dụng',
        'candidateName': 'Nguyễn An',
      },
    );
    final repository = _FakeNotificationRepository(
      CandidateNotificationList(
        items: [notification],
        summary: const CandidateNotificationSummary(total: 1, unread: 0),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          candidateNotificationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: CandidateNotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hồ sơ chưa được duyệt'));
    await tester.pumpAndSettle();

    expect(find.text('Ngày'), findsOneWidget);
    expect(find.text('08/07/2026'), findsOneWidget);

    final toneIndicator = tester.widget<Container>(
      find.byKey(const Key('notification-tone-indicator')),
    );
    final decoration = toneIndicator.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFFFEE2E2));
  });

  testWidgets('notification detail resolves employer name from related job', (
    tester,
  ) async {
    final notification = CandidateNotification(
      id: 'n-job-name',
      type: CandidateNotificationType.cvAccepted,
      title: 'CV của bạn đã được NTD duyệt',
      body:
          'CV của bạn cho vị trí Thu ngân quán tại Nhà tuyển dụng đã được thông qua.',
      status: CandidateNotificationStatus.read,
      createdAt: DateTime.parse('2026-07-08T14:25:00Z'),
      data: const {'jobId': 'job-katinat', 'candidateName': 'Nguyễn An'},
    );
    final repository = _FakeNotificationRepository(
      CandidateNotificationList(
        items: [notification],
        summary: const CandidateNotificationSummary(total: 1, unread: 0),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          candidateNotificationRepositoryProvider.overrideWithValue(repository),
          activeJobsProvider.overrideWith((_) async => [_katinatJob]),
          activeQuickJobsProvider.overrideWith((_) async => <JobPost>[]),
        ],
        child: const MaterialApp(home: CandidateNotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CV của bạn đã được NTD duyệt'));
    await tester.pumpAndSettle();

    expect(
      find.text('CV của bạn đã được Katinat Quận Cam duyệt'),
      findsOneWidget,
    );
    expect(
      find.text(
        'CV của bạn cho vị trí Thu ngân quán tại Katinat Quận Cam đã được thông qua.',
      ),
      findsOneWidget,
    );
    expect(find.text('Người gửi'), findsOneWidget);
    expect(find.text('Katinat Quận Cam'), findsWidgets);
    expect(find.textContaining('Nhà tuyển dụng'), findsNothing);
    expect(find.textContaining('NTD'), findsNothing);
  });

  testWidgets('opens notification detail even when marking read fails', (
    tester,
  ) async {
    final notification = CandidateNotification(
      id: 'n1',
      type: CandidateNotificationType.cvAccepted,
      title: 'CV mới từ nhà tuyển dụng',
      body: 'Nhà tuyển dụng vừa gửi phản hồi mới cho hồ sơ của bạn.',
      status: CandidateNotificationStatus.unread,
      createdAt: DateTime.parse('2026-07-06T10:00:00Z'),
    );
    final repository = _FakeNotificationRepository(
      CandidateNotificationList(
        items: [notification],
        summary: const CandidateNotificationSummary(total: 1, unread: 1),
      ),
      failMarkAsRead: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          candidateNotificationRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: CandidateNotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CV mới từ nhà tuyển dụng'));
    await tester.pumpAndSettle();

    expect(repository.readIds, ['n1']);
    expect(find.text('Chi tiết thông báo'), findsOneWidget);
    expect(
      find.text('Nhà tuyển dụng vừa gửi phản hồi mới cho hồ sơ của bạn.'),
      findsOneWidget,
    );
  });
}

class _FakeNotificationRepository implements CandidateNotificationRepository {
  _FakeNotificationRepository(this.list, {this.failMarkAsRead = false});

  CandidateNotificationList list;
  final bool failMarkAsRead;
  final readIds = <String>[];

  @override
  Future<CandidateNotificationList> listNotifications({
    String status = 'all',
    int limit = 20,
    String? nextToken,
  }) async {
    return list;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    readIds.add(notificationId);
    if (failMarkAsRead) {
      throw Exception('mark read failed');
    }
  }

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> archive(String notificationId) async {}
}

final _katinatJob = JobPost(
  id: 'job-katinat',
  idJob: 'JOB-20260708-NU2ZU',
  employerId: 'employer-katinat',
  employerName: 'Katinat Quận Cam',
  companyName: 'Katinat Quận Cam',
  title: 'Thu ngân quán',
  jobType: JobPostType.partTime,
  location: 'Quận 2',
  salary: '25.000đ/giờ',
  shiftTime: '07:00 - 11:30',
  description: 'Thu ngân tại quán.',
  tags: const ['F&B'],
  postedAt: DateTime(2026, 7, 1),
);
