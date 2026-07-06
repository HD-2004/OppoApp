import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/application/notification_controller.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/application/notification_providers.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_repository.dart';

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
