import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/notification_repository.dart';
import 'notification_providers.dart';

const _emptyNotificationList = CandidateNotificationList(
  items: [],
  summary: CandidateNotificationSummary(total: 0, unread: 0),
);
const _notificationListLimit = 50;
const _notificationRefreshInterval = Duration(minutes: 2);
const _notificationFailureBackoff = Duration(minutes: 5);

final candidateNotificationControllerProvider =
    AsyncNotifierProvider<
      CandidateNotificationController,
      CandidateNotificationList
    >(CandidateNotificationController.new);

class CandidateNotificationController
    extends AsyncNotifier<CandidateNotificationList> {
  Timer? _refreshTimer;
  DateTime? _nextAutomaticRefreshAt;

  CandidateNotificationRepository get _repository =>
      ref.read(candidateNotificationRepositoryProvider);

  CandidateNotificationList get _currentNotifications =>
      state.asData?.value ?? _emptyNotificationList;

  @override
  Future<CandidateNotificationList> build() async {
    final repository = ref.watch(candidateNotificationRepositoryProvider);
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      _notificationRefreshInterval,
      (_) => _refreshSilently(),
    );
    ref.onDispose(() => _refreshTimer?.cancel());

    try {
      final notifications = await repository.listNotifications(
        limit: _notificationListLimit,
      );
      _clearFailureBackoff();
      return notifications;
    } catch (_) {
      _recordFailure();
      return _emptyNotificationList;
    }
  }

  Future<void> _refreshSilently() async {
    if (_isWaitingForBackendRecovery()) {
      return;
    }
    await _reloadNotifications();
  }

  Future<void> _reloadNotifications() async {
    final previous = _currentNotifications;
    try {
      final notifications = await _repository.listNotifications(
        limit: _notificationListLimit,
      );
      _clearFailureBackoff();
      state = AsyncData(notifications);
    } catch (_) {
      _recordFailure();
      state = AsyncData(previous);
    }
  }

  Future<void> refreshNotifications() async {
    await _reloadNotifications();
  }

  Future<void> markAsRead(String notificationId) async {
    await _repository.markAsRead(notificationId);
    await _reloadNotifications();
  }

  Future<void> markAllAsRead() async {
    await _repository.markAllAsRead();
    await _reloadNotifications();
  }

  Future<void> archive(String notificationId) async {
    await _repository.archive(notificationId);
    await _reloadNotifications();
  }

  bool _isWaitingForBackendRecovery() {
    final nextRefreshAt = _nextAutomaticRefreshAt;
    return nextRefreshAt != null && DateTime.now().isBefore(nextRefreshAt);
  }

  void _recordFailure() {
    _nextAutomaticRefreshAt = DateTime.now().add(_notificationFailureBackoff);
  }

  void _clearFailureBackoff() {
    _nextAutomaticRefreshAt = null;
  }
}
