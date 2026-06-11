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
