import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/http_notification_repository.dart';
import '../data/notification_remote_data_source.dart';
import '../domain/notification_repository.dart';

final candidateNotificationRepositoryProvider =
    Provider<CandidateNotificationRepository>((ref) {
  return HttpCandidateNotificationRepository(NotificationRemoteDataSource());
});
