import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/data/http_notification_repository.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/data/notification_remote_data_source.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_status.dart';
import 'package:oppo_temp_jobs/features/candidate/notifications/domain/notification_type.dart';

void main() {
  group('HttpCandidateNotificationRepository', () {
    test(
      'syncs candidate notifications from the shared website endpoint',
      () async {
        final requests = <http.Request>[];
        final repository = HttpCandidateNotificationRepository(
          NotificationRemoteDataSource(
            baseUrl: 'https://notifications.example.com',
            client: MockClient((request) async {
              requests.add(request);
              expect(request.method, 'GET');
              expect(request.url.path, '/notifications');
              expect(request.url.queryParameters['recipientRole'], 'candidate');
              expect(request.url.queryParameters['recipientId'], 'candidate-1');
              expect(request.url.queryParameters['limit'], '50');

              return http.Response(
                jsonEncode([
                  {
                    'notificationId': 'n-candidate',
                    'type': 'success',
                    'title': 'CV của bạn đã được chấp nhận',
                    'message':
                        'CV của bạn đã được Katinat chấp nhận cho vị trí thu ngân.',
                    'recipientRole': 'candidate',
                    'recipientId': 'candidate-1',
                    'read': false,
                    'deleted': false,
                    'actionUrl': '/candidate/applications',
                    'createdAt': '2026-07-06T05:04:52.796589+00:00',
                  },
                  {
                    'notificationId': 'n-employer',
                    'type': 'application',
                    'title': 'Ứng viên mới ứng tuyển',
                    'message': 'Một ứng viên mới vừa ứng tuyển.',
                    'recipientRole': 'employer',
                    'recipientId': 'employer-1',
                    'read': false,
                    'deleted': false,
                    'createdAt': '2026-07-06T05:05:52.796589+00:00',
                  },
                  {
                    'notificationId': 'n-deleted',
                    'type': 'system',
                    'title': 'Thông báo đã xoá',
                    'message': 'Thông báo này không còn hiển thị.',
                    'recipientRole': 'candidate',
                    'recipientId': 'candidate-1',
                    'read': false,
                    'deleted': true,
                    'createdAt': '2026-07-06T05:06:52.796589+00:00',
                  },
                ]),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }),
            tokenProvider: () async => 'auth-token',
            userIdProvider: () async => 'candidate-1',
          ),
        );

        final notifications = await repository.listNotifications(limit: 50);

        expect(requests, hasLength(1));
        expect(requests.single.headers['Authorization'], 'Bearer auth-token');
        expect(notifications.items, hasLength(1));
        expect(notifications.summary.total, 1);
        expect(notifications.summary.unread, 1);

        final notification = notifications.items.single;
        expect(notification.id, 'n-candidate');
        expect(notification.type, CandidateNotificationType.cvAccepted);
        expect(notification.status, CandidateNotificationStatus.unread);
        expect(notification.title, 'CV của bạn đã được chấp nhận');
        expect(notification.body, contains('Katinat'));
        expect(notification.deepLink, '/candidate/applications');
      },
    );

    test('does not fetch the shared feed without a current candidate id', () {
      var requested = false;
      final repository = HttpCandidateNotificationRepository(
        NotificationRemoteDataSource(
          baseUrl: 'https://notifications.example.com',
          client: MockClient((request) async {
            requested = true;
            return http.Response('[]', 200);
          }),
          userIdProvider: () async => null,
        ),
      );

      expect(repository.listNotifications(), throwsA(isA<StateError>()));
      expect(requested, isFalse);
    });

    test('marks notifications read using the live API update route', () async {
      final requests = <http.Request>[];
      final repository = HttpCandidateNotificationRepository(
        NotificationRemoteDataSource(
          baseUrl: 'https://notifications.example.com',
          client: MockClient((request) async {
            requests.add(request);
            return http.Response(jsonEncode({'success': true}), 200);
          }),
          tokenProvider: () async => 'auth-token',
          userIdProvider: () async => 'candidate-1',
        ),
      );

      await repository.markAsRead('NOTIF-1');
      await repository.markAllAsRead();
      await repository.archive('NOTIF-2');

      expect(requests.map((request) => request.method), [
        'PUT',
        'PUT',
        'DELETE',
      ]);
      expect(requests.map((request) => request.url.path), [
        '/notifications/NOTIF-1',
        '/notifications/mark-all-read/candidate-1',
        '/notifications/NOTIF-2',
      ]);
      expect(jsonDecode(requests.first.body), {'read': true});
      expect(requests.first.headers['Authorization'], 'Bearer auth-token');
    });
  });
}
