import 'candidate_notification.dart';

class CandidateNotificationSummary {
  const CandidateNotificationSummary({
    required this.total,
    required this.unread,
  });

  final int total;
  final int unread;
}

class CandidateNotificationList {
  const CandidateNotificationList({
    required this.items,
    required this.summary,
    this.nextToken,
  });

  final List<CandidateNotification> items;
  final CandidateNotificationSummary summary;
  final String? nextToken;
}

abstract class CandidateNotificationRepository {
  Future<CandidateNotificationList> listNotifications({
    String status = 'all',
    int limit = 20,
    String? nextToken,
  });

  Future<void> markAsRead(String notificationId);

  Future<void> markAllAsRead();

  Future<void> archive(String notificationId);
}
