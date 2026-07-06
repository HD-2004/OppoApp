import '../domain/candidate_notification.dart';

enum CandidateNotificationDestinationKind {
  notificationDetail,
  route,
  applicationDetail,
  applicationList,
  messages,
  wallet,
  profile,
}

class CandidateNotificationDestination {
  const CandidateNotificationDestination({
    required this.kind,
    required this.label,
    this.route,
    this.entityId,
  });

  final CandidateNotificationDestinationKind kind;
  final String label;
  final String? route;
  final String? entityId;

  bool get hasAction =>
      kind != CandidateNotificationDestinationKind.notificationDetail;
}

CandidateNotificationDestination resolveCandidateNotificationDestination(
  CandidateNotification notification,
) {
  final uri = _notificationUri(notification.deepLink);
  final segments =
      uri?.pathSegments
          .where((segment) => segment.trim().isNotEmpty)
          .toList(growable: false) ??
      const <String>[];
  final normalizedSegments = segments
      .map((segment) => segment.trim().toLowerCase())
      .toList(growable: false);
  final entityType = _normalize(notification.entityType);
  final entityId = notification.entityId?.trim();

  if (normalizedSegments.length >= 2 && normalizedSegments.first == 'jobs') {
    return CandidateNotificationDestination(
      kind: CandidateNotificationDestinationKind.route,
      label: 'Xem công việc',
      route: '/jobs/${Uri.encodeComponent(segments[1])}',
      entityId: segments[1],
    );
  }

  if (normalizedSegments.length >= 2 &&
      normalizedSegments.first == 'bookings') {
    return CandidateNotificationDestination(
      kind: CandidateNotificationDestinationKind.route,
      label: 'Xem ca làm',
      route: '/bookings/${Uri.encodeComponent(segments[1])}',
      entityId: segments[1],
    );
  }

  if (_isApplicationPath(normalizedSegments) || entityType == 'application') {
    final applicationId =
        _applicationIdFromPath(segments, normalizedSegments) ??
        _applicationEntityId(notification) ??
        (entityType == 'application' ? entityId : null);
    if (applicationId != null) {
      return CandidateNotificationDestination(
        kind: CandidateNotificationDestinationKind.applicationDetail,
        label: 'Xem hồ sơ ứng tuyển',
        entityId: applicationId,
      );
    }

    return const CandidateNotificationDestination(
      kind: CandidateNotificationDestinationKind.applicationList,
      label: 'Xem hồ sơ ứng tuyển',
    );
  }

  if (_isMessagesPath(normalizedSegments) || entityType == 'message') {
    return CandidateNotificationDestination(
      kind: CandidateNotificationDestinationKind.messages,
      label: 'Mở tin nhắn',
      entityId: entityType == 'message'
          ? _messageEntityId(notification)
          : _lastSegment(segments),
    );
  }

  if (_isWalletPath(normalizedSegments) ||
      entityType == 'payment' ||
      entityType == 'wallet') {
    return const CandidateNotificationDestination(
      kind: CandidateNotificationDestinationKind.wallet,
      label: 'Mở ví',
    );
  }

  if (_isProfilePath(normalizedSegments) ||
      entityType == 'profile' ||
      entityType == 'kyc') {
    return const CandidateNotificationDestination(
      kind: CandidateNotificationDestinationKind.profile,
      label: 'Mở hồ sơ',
    );
  }

  if (entityType == 'job' && entityId?.isNotEmpty == true) {
    final id = entityId!;
    return CandidateNotificationDestination(
      kind: CandidateNotificationDestinationKind.route,
      label: 'Xem công việc',
      route: '/jobs/${Uri.encodeComponent(id)}',
      entityId: id,
    );
  }

  if (entityType == 'booking' && entityId?.isNotEmpty == true) {
    final id = entityId!;
    return CandidateNotificationDestination(
      kind: CandidateNotificationDestinationKind.route,
      label: 'Xem ca làm',
      route: '/bookings/${Uri.encodeComponent(id)}',
      entityId: id,
    );
  }

  return const CandidateNotificationDestination(
    kind: CandidateNotificationDestinationKind.notificationDetail,
    label: 'Chi tiết thông báo',
  );
}

String? _messageEntityId(CandidateNotification notification) {
  return _firstNonEmpty([
    notification.entityId,
    notification.data['applicationId'],
    notification.data['conversationId'],
    notification.data['chatId'],
  ]);
}

Uri? _notificationUri(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  return Uri.tryParse(raw);
}

bool _isApplicationPath(List<String> segments) {
  if (segments.length < 2) return false;
  return segments[0] == 'candidate' && segments[1] == 'applications';
}

String? _applicationIdFromPath(
  List<String> segments,
  List<String> normalizedSegments,
) {
  if (!_isApplicationPath(normalizedSegments) || segments.length < 3) {
    return null;
  }
  return segments[2].trim().isEmpty ? null : segments[2].trim();
}

String? _applicationEntityId(CandidateNotification notification) {
  for (final value in [
    notification.entityId,
    notification.data['applicationId'],
    notification.data['appId'],
    notification.data['id'],
  ]) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return null;
}

bool _isMessagesPath(List<String> segments) {
  if (segments.isEmpty) return false;
  if (segments.first == 'messages' || segments.first == 'chat') return true;
  return segments.length >= 2 &&
      segments.first == 'candidate' &&
      (segments[1] == 'messages' || segments[1] == 'chat');
}

bool _isWalletPath(List<String> segments) {
  return segments.length >= 2 &&
      segments.first == 'candidate' &&
      (segments[1] == 'wallet' || segments[1] == 'payments');
}

bool _isProfilePath(List<String> segments) {
  return segments.length >= 2 &&
      segments.first == 'candidate' &&
      (segments[1] == 'profile' ||
          segments[1] == 'settings' ||
          segments[1] == 'kyc');
}

String? _lastSegment(List<String> segments) {
  if (segments.isEmpty) return null;
  final text = segments.last.trim();
  return text.isEmpty ? null : text;
}

String? _firstNonEmpty(List<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return null;
}

String _normalize(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '';
  final separated = text.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match[1]}_${match[2]}',
  );
  return separated.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
}
