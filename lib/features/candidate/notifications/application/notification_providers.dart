import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/auth_controller.dart';
import '../data/http_notification_repository.dart';
import '../data/notification_remote_data_source.dart';
import '../domain/notification_repository.dart';

final candidateNotificationRepositoryProvider =
    Provider<CandidateNotificationRepository>(
      _createCandidateNotificationRepository,
    );

CandidateNotificationRepository _createCandidateNotificationRepository(
  Ref ref,
) {
  final userId = ref.watch(authControllerProvider).asData?.value.user?.userId;
  return HttpCandidateNotificationRepository(
    NotificationRemoteDataSource(userIdProvider: () async => userId),
  );
}
