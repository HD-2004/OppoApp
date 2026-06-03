import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notification_repository.dart';
import 'notification_providers.dart';

final candidateNotificationControllerProvider = AsyncNotifierProvider<
    CandidateNotificationController, CandidateNotificationList>(
  CandidateNotificationController.new,
);

class CandidateNotificationController
    extends AsyncNotifier<CandidateNotificationList> {
  CandidateNotificationRepository get _repository =>
      ref.read(candidateNotificationRepositoryProvider);

  @override
  Future<CandidateNotificationList> build() {
    return _repository.listNotifications(limit: 50);
  }

  Future<void> refreshNotifications() async {
    state = const AsyncLoading<CandidateNotificationList>();
    state = await AsyncValue.guard(() => _repository.listNotifications(limit: 50));
  }

  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
    state = await AsyncValue.guard(() => _repository.listNotifications(limit: 50));
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    state = await AsyncValue.guard(() => _repository.listNotifications(limit: 50));
  }

  Future<void> archive(String notificationId) async {
    await _repository.archive(notificationId);
    state = await AsyncValue.guard(() => _repository.listNotifications(limit: 50));
  }
}
