import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notification_repository.dart';
import 'notification_providers.dart';

const _emptyNotificationList = CandidateNotificationList(
  items: [],
  summary: CandidateNotificationSummary(total: 0, unread: 0),
);

final candidateNotificationControllerProvider =
    AsyncNotifierProvider<
      CandidateNotificationController,
      CandidateNotificationList
    >(CandidateNotificationController.new);

class CandidateNotificationController
    extends AsyncNotifier<CandidateNotificationList> {
  Timer? _refreshTimer;

  CandidateNotificationRepository get _repository =>
      ref.read(candidateNotificationRepositoryProvider);

  @override
  Future<CandidateNotificationList> build() async {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshSilently(),
    );
    ref.onDispose(() => _refreshTimer?.cancel());

    try {
      return await _repository.listNotifications(limit: 50);
    } catch (_) {
      return _emptyNotificationList;
    }
  }

  Future<void> _refreshSilently() async {
    try {
      final notifications = await _repository.listNotifications(limit: 50);
      state = AsyncData(notifications);
    } catch (_) {
      // Keep the last successful notification count while polling.
    }
  }

  Future<void> refreshNotifications() async {
    state = const AsyncLoading<CandidateNotificationList>();
    state = await AsyncValue.guard(
      () => _repository.listNotifications(limit: 50),
    );
  }

  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
    state = await AsyncValue.guard(
      () => _repository.listNotifications(limit: 50),
    );
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    state = await AsyncValue.guard(
      () => _repository.listNotifications(limit: 50),
    );
  }

  Future<void> archive(String notificationId) async {
    await _repository.archive(notificationId);
    state = await AsyncValue.guard(
      () => _repository.listNotifications(limit: 50),
    );
  }
}
