import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/application/notification_controller.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/application/notification_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/candidate_notification.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_status.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_type.dart';

void main() {
  test('returns an empty notification list when initial load fails', () async {
    final container = ProviderContainer(
      overrides: [
        candidateNotificationRepositoryProvider.overrideWithValue(
          const _FailingNotificationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifications = await container.read(
      candidateNotificationControllerProvider.future,
    );

    expect(notifications.items, isEmpty);
    expect(notifications.summary.total, 0);
    expect(notifications.summary.unread, 0);
  });

  test(
    'reloads notifications when the repository dependency changes',
    () async {
      var activeRepository = const _StaticNotificationRepository(total: 1);
      final activeRepositoryProvider =
          Provider<CandidateNotificationRepository>((_) => activeRepository);
      final container = ProviderContainer(
        overrides: [
          candidateNotificationRepositoryProvider.overrideWith(
            (ref) => ref.watch(activeRepositoryProvider),
          ),
        ],
      );
      addTearDown(container.dispose);

      final initial = await container.read(
        candidateNotificationControllerProvider.future,
      );
      expect(initial.summary.total, 1);

      activeRepository = const _StaticNotificationRepository(total: 2);
      container.invalidate(activeRepositoryProvider);
      await Future<void>.delayed(Duration.zero);

      final reloaded = await container.read(
        candidateNotificationControllerProvider.future,
      );
      expect(reloaded.summary.total, 2);
    },
  );

  test('keeps current notifications when a manual refresh fails', () async {
    final repository = _FlakyListNotificationRepository(
      firstList: _notificationList(total: 1),
    );
    final container = ProviderContainer(
      overrides: [
        candidateNotificationRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final initial = await container.read(
      candidateNotificationControllerProvider.future,
    );
    expect(initial.summary.total, 1);

    await container
        .read(candidateNotificationControllerProvider.notifier)
        .refreshNotifications();

    final state = container.read(candidateNotificationControllerProvider);
    expect(state.hasError, isFalse);
    expect(state.asData?.value.summary.total, 1);
    expect(repository.listCallCount, 2);
  });

  test(
    'keeps current notifications when reload after mark read fails',
    () async {
      final repository = _FlakyListNotificationRepository(
        firstList: _notificationList(total: 1),
      );
      final container = ProviderContainer(
        overrides: [
          candidateNotificationRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(candidateNotificationControllerProvider.future);

      await container
          .read(candidateNotificationControllerProvider.notifier)
          .markAsRead('NOTIF-1');

      final state = container.read(candidateNotificationControllerProvider);
      expect(repository.readIds, ['NOTIF-1']);
      expect(state.hasError, isFalse);
      expect(state.asData?.value.summary.total, 1);
      expect(repository.listCallCount, 2);
    },
  );
}

CandidateNotificationList _notificationList({required int total}) {
  return CandidateNotificationList(
    items: [
      CandidateNotification(
        id: 'NOTIF-1',
        type: CandidateNotificationType.system,
        title: 'Thông báo mới',
        body: 'Bạn có cập nhật mới.',
        status: CandidateNotificationStatus.unread,
        createdAt: DateTime.parse('2026-07-13T08:00:00Z'),
      ),
    ],
    summary: CandidateNotificationSummary(total: total, unread: 1),
  );
}

class _FailingNotificationRepository
    implements CandidateNotificationRepository {
  const _FailingNotificationRepository();

  @override
  Future<CandidateNotificationList> listNotifications({
    String status = 'all',
    int limit = 20,
    String? nextToken,
  }) {
    throw Exception('network unavailable');
  }

  @override
  Future<void> archive(String notificationId) async {}

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> markAsRead(String notificationId) async {}
}

class _StaticNotificationRepository implements CandidateNotificationRepository {
  const _StaticNotificationRepository({required this.total});

  final int total;

  @override
  Future<CandidateNotificationList> listNotifications({
    String status = 'all',
    int limit = 20,
    String? nextToken,
  }) async {
    return CandidateNotificationList(
      items: const [],
      summary: CandidateNotificationSummary(total: total, unread: 0),
    );
  }

  @override
  Future<void> archive(String notificationId) async {}

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> markAsRead(String notificationId) async {}
}

class _FlakyListNotificationRepository
    implements CandidateNotificationRepository {
  _FlakyListNotificationRepository({required this.firstList});

  final CandidateNotificationList firstList;
  final readIds = <String>[];
  int listCallCount = 0;

  @override
  Future<CandidateNotificationList> listNotifications({
    String status = 'all',
    int limit = 20,
    String? nextToken,
  }) async {
    listCallCount += 1;
    if (listCallCount == 1) {
      return firstList;
    }
    throw Exception('DynamoDB throughput exceeded');
  }

  @override
  Future<void> archive(String notificationId) async {}

  @override
  Future<void> markAllAsRead() async {}

  @override
  Future<void> markAsRead(String notificationId) async {
    readIds.add(notificationId);
  }
}
