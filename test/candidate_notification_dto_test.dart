import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/data/notification_dto.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_status.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_type.dart';

void main() {
  test('parses backend notification dto with body and unread status', () {
    final notification = NotificationDto.fromJson({
      'id': 'n1',
      'type': 'CV_ACCEPTED',
      'title': 'CV của bạn đã được chấp nhận',
      'body': 'CV của bạn đã được Katinat chấp nhận cho vị trí Nhân viên.',
      'status': 'UNREAD',
      'priority': 'NORMAL',
      'entityType': 'APPLICATION',
      'entityId': 'app1',
      'deepLink': '/candidate/applications/app1',
      'createdAt': '2026-06-02T10:00:00Z',
      'readAt': null,
    }).toDomain();

    expect(notification.id, 'n1');
    expect(notification.type, CandidateNotificationType.cvAccepted);
    expect(notification.status, CandidateNotificationStatus.unread);
    expect(notification.body, contains('Katinat'));
    expect(notification.deepLink, '/candidate/applications/app1');
  });

  test('uses legacy message when body is absent', () {
    final notification = NotificationDto.fromJson({
      'notificationId': 'legacy1',
      'type': 'NEW_MESSAGE',
      'title': 'Tin nhắn mới',
      'message': 'Bạn có tin nhắn mới từ Nhà tuyển dụng',
      'read': true,
      'createdAt': '2026-06-02T10:00:00Z',
    }).toDomain();

    expect(notification.id, 'legacy1');
    expect(notification.type, CandidateNotificationType.newMessage);
    expect(notification.status, CandidateNotificationStatus.read);
    expect(notification.body, 'Bạn có tin nhắn mới từ Nhà tuyển dụng');
  });
}
