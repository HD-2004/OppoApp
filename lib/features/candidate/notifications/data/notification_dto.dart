import '../domain/candidate_notification.dart';
import '../domain/notification_status.dart';
import '../domain/notification_type.dart';

class NotificationDto {
  const NotificationDto({
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

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    final readValue = json['read'];
    final createdAtValue = json['createdAt'] as String?;
    final readAtValue = json['readAt'] as String?;
    final rawData = json['data'];
    return NotificationDto(
      id: (json['id'] ?? json['notificationId'] ?? '').toString(),
      type: (json['type'] ?? 'SYSTEM').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? json['message'] ?? '').toString(),
      status: CandidateNotificationStatus.fromWire(
        json['status'] as String?,
        read: readValue is bool ? readValue : null,
      ),
      createdAt:
          DateTime.tryParse(createdAtValue ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      entityType: json['entityType']?.toString(),
      entityId: json['entityId']?.toString(),
      deepLink: (json['deepLink'] ?? json['actionUrl'])?.toString(),
      readAt: readAtValue == null
          ? null
          : DateTime.tryParse(readAtValue)?.toLocal(),
      data: rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : const <String, dynamic>{},
    );
  }

  final String id;
  final String type;
  final String title;
  final String body;
  final CandidateNotificationStatus status;
  final DateTime createdAt;
  final String? entityType;
  final String? entityId;
  final String? deepLink;
  final DateTime? readAt;
  final Map<String, dynamic> data;

  CandidateNotification toDomain() {
    return CandidateNotification(
      id: id,
      type: CandidateNotificationType.fromWire(type),
      title: title,
      body: body,
      status: status,
      createdAt: createdAt,
      entityType: entityType,
      entityId: entityId,
      deepLink: deepLink,
      readAt: readAt,
      data: data,
    );
  }
}
