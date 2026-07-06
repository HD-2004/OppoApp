import 'package:flutter_test/flutter_test.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/application/notification_navigation.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/candidate_notification.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_status.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_type.dart';

void main() {
  test('maps website application detail links to mobile application detail', () {
    final destination = resolveCandidateNotificationDestination(
      _notification(
        deepLink: 'https://oppo.example.com/candidate/applications/app-1',
        entityType: 'APPLICATION',
      ),
    );

    expect(
      destination.kind,
      CandidateNotificationDestinationKind.applicationDetail,
    );
    expect(destination.entityId, 'app-1');
    expect(destination.route, isNull);
    expect(destination.label, 'Xem hồ sơ ứng tuyển');
  });

  test('uses notification entity id for application links without an id', () {
    final destination = resolveCandidateNotificationDestination(
      _notification(
        deepLink: '/candidate/applications',
        entityType: 'APPLICATION',
        entityId: 'app-from-entity',
      ),
    );

    expect(
      destination.kind,
      CandidateNotificationDestinationKind.applicationDetail,
    );
    expect(destination.entityId, 'app-from-entity');
  });

  test('keeps supported job and booking links as router routes', () {
    final jobDestination = resolveCandidateNotificationDestination(
      _notification(deepLink: '/jobs/job-1'),
    );
    final bookingDestination = resolveCandidateNotificationDestination(
      _notification(deepLink: '/bookings/booking-1'),
    );

    expect(jobDestination.kind, CandidateNotificationDestinationKind.route);
    expect(jobDestination.route, '/jobs/job-1');
    expect(jobDestination.label, 'Xem công việc');
    expect(
      bookingDestination.kind,
      CandidateNotificationDestinationKind.route,
    );
    expect(bookingDestination.route, '/bookings/booking-1');
    expect(bookingDestination.label, 'Xem ca làm');
  });

  test('falls back to notification detail for unsupported links', () {
    final destination = resolveCandidateNotificationDestination(
      _notification(deepLink: '/employer/standard-jobs'),
    );

    expect(
      destination.kind,
      CandidateNotificationDestinationKind.notificationDetail,
    );
    expect(destination.route, isNull);
  });
}

CandidateNotification _notification({
  String? deepLink,
  String? entityType,
  String? entityId,
}) {
  return CandidateNotification(
    id: 'n1',
    type: CandidateNotificationType.cvAccepted,
    title: 'CV được chấp nhận',
    body: 'Hồ sơ của bạn đã được chấp nhận.',
    status: CandidateNotificationStatus.unread,
    createdAt: DateTime.parse('2026-07-06T10:00:00Z'),
    entityType: entityType,
    entityId: entityId,
    deepLink: deepLink,
  );
}
