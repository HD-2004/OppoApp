import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/application/notification_providers.dart';
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
