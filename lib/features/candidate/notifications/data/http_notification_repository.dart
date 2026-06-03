import '../domain/candidate_notification.dart';
import '../domain/notification_repository.dart';
import 'notification_dto.dart';
import 'notification_remote_data_source.dart';

class HttpCandidateNotificationRepository
    implements CandidateNotificationRepository {
  HttpCandidateNotificationRepository(this._remote);

  final NotificationRemoteDataSource _remote;

  @override
  Future<CandidateNotificationList> listNotifications({
    String status = 'all',
    int limit = 20,
    String? nextToken,
  }) async {
    final json = await _remote.listNotifications(
      status: status,
      limit: limit,
      nextToken: nextToken,
    );
    final rawItems = json['items'];
    final List<CandidateNotification> items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => NotificationDto.fromJson(Map<String, dynamic>.from(item)).toDomain())
            .toList()
        : const <CandidateNotification>[];
    final rawSummary = json['summary'];
    final summary = rawSummary is Map
        ? CandidateNotificationSummary(
            total: (rawSummary['total'] as num?)?.toInt() ?? items.length,
            unread: (rawSummary['unread'] as num?)?.toInt() ??
                items.where((item) => item.isUnread).length,
          )
        : CandidateNotificationSummary(
            total: items.length,
            unread: items.where((item) => item.isUnread).length,
          );

    return CandidateNotificationList(
      items: items,
      summary: summary,
      nextToken: json['nextToken']?.toString(),
    );
  }

  @override
  Future<void> markAsRead(String notificationId) {
    return _remote.markAsRead(notificationId);
  }

  @override
  Future<void> markAllAsRead() {
    return _remote.markAllAsRead();
  }

  @override
  Future<void> archive(String notificationId) {
    return _remote.archive(notificationId);
  }
}
