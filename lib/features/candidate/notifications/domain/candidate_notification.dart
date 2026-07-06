import 'notification_status.dart';
import 'notification_type.dart';

class CandidateNotification {
  const CandidateNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.status,
    required this.createdAt,
    this.entityType,
    this.entityId,
    this.deepLink,
    this.readAt,
    this.data = const {},
  });

  final String id;
  final CandidateNotificationType type;
  final String title;
  final String body;
  final CandidateNotificationStatus status;
  final DateTime createdAt;
  final String? entityType;
  final String? entityId;
  final String? deepLink;
  final DateTime? readAt;
  final Map<String, dynamic> data;

  bool get isUnread => status == CandidateNotificationStatus.unread;

  CandidateNotification copyWith({
    CandidateNotificationStatus? status,
    DateTime? readAt,
  }) {
    return CandidateNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      status: status ?? this.status,
      createdAt: createdAt,
      entityType: entityType,
      entityId: entityId,
      deepLink: deepLink,
      readAt: readAt ?? this.readAt,
      data: data,
    );
  }
}
