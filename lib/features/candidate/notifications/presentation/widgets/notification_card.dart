import 'package:flutter/material.dart';

import '../../domain/candidate_notification.dart';
import '../../domain/notification_type.dart';

class CandidateNotificationCard extends StatelessWidget {
  const CandidateNotificationCard({
    required this.notification,
    required this.onTap,
    super.key,
  });

  final CandidateNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _colors(notification.type);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.foreground.withValues(alpha: 0.2)),
          ),
          child: Icon(_icon(notification.type), color: colors.foreground, size: 24),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    notification.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _relativeTime(notification.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              notification.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _NotificationColors {
  const _NotificationColors(this.foreground, this.background);

  final Color foreground;
  final Color background;
}

_NotificationColors _colors(CandidateNotificationType type) {
  switch (type) {
    case CandidateNotificationType.cvAccepted:
    case CandidateNotificationType.shiftAccepted:
    case CandidateNotificationType.shiftConfirmed:
    case CandidateNotificationType.shiftCompleted:
    case CandidateNotificationType.kycApproved:
      return const _NotificationColors(Color(0xFF16A34A), Color(0xFFF0FDF4));
    case CandidateNotificationType.newMessage:
      return const _NotificationColors(Color(0xFFEA580C), Color(0xFFFFF7ED));
    case CandidateNotificationType.cvRejected:
    case CandidateNotificationType.paymentFailed:
    case CandidateNotificationType.kycRejected:
      return const _NotificationColors(Color(0xFFEF4444), Color(0xFFFEF2F2));
    case CandidateNotificationType.profileViewed:
    case CandidateNotificationType.paymentReleased:
    case CandidateNotificationType.jobRecommended:
    case CandidateNotificationType.system:
      return const _NotificationColors(Color(0xFF1E40AF), Color(0xFFEFF6FF));
  }
}

IconData _icon(CandidateNotificationType type) {
  switch (type) {
    case CandidateNotificationType.profileViewed:
      return Icons.visibility;
    case CandidateNotificationType.newMessage:
      return Icons.chat_bubble_outline;
    case CandidateNotificationType.cvAccepted:
    case CandidateNotificationType.shiftAccepted:
    case CandidateNotificationType.shiftConfirmed:
    case CandidateNotificationType.shiftCompleted:
    case CandidateNotificationType.paymentReleased:
    case CandidateNotificationType.kycApproved:
      return Icons.check_circle_outline;
    case CandidateNotificationType.cvRejected:
    case CandidateNotificationType.paymentFailed:
    case CandidateNotificationType.kycRejected:
      return Icons.error_outline;
    case CandidateNotificationType.jobRecommended:
      return Icons.work_outline;
    case CandidateNotificationType.system:
      return Icons.notifications_none;
  }
}

String _relativeTime(DateTime createdAt) {
  final now = DateTime.now();
  final diff = now.difference(createdAt);
  if (diff.inMinutes < 1) return 'Vừa xong';
  if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
  if (diff.inDays < 1) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  final weeks = (diff.inDays / 7).floor();
  return '$weeks tuần trước';
}
