import 'package:flutter/material.dart';

import '../../domain/candidate_notification.dart';
import '../../domain/notification_type.dart';

class CandidateNotificationCard extends StatelessWidget {
  const CandidateNotificationCard({
    required this.notification,
    required this.onTap,
    this.onArchive,
    super.key,
  });

  final CandidateNotification notification;
  final VoidCallback onTap;

  /// Optional — trượt hoặc long-press để lưu trữ thông báo
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    final colors = _colorFor(notification.type);
    final isUnread = notification.isUnread;

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF6B7280).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.archive_outlined, color: Color(0xFF6B7280), size: 22),
            SizedBox(height: 4),
            Text(
              'Lưu trữ',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        if (onArchive != null) {
          onArchive!();
          return true;
        }
        return false;
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isUnread
                ? const Color(0xFFF0F4FF) // nền nhạt xanh khi chưa đọc
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isUnread
                  ? const Color(0xFF1E3A8A).withValues(alpha: 0.15)
                  : const Color(0xFFE5E7EB),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Icon box ───────────────────────────────────────────
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconFor(notification.type),
                    color: colors.foreground,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // ── Content ────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row + time
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: const Color(0xFF111827),
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _relativeTime(notification.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Body
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 13,
                          color: isUnread
                              ? const Color(0xFF374151)
                              : const Color(0xFF6B7280),
                          height: 1.45,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // ── Unread dot ─────────────────────────────────────────
                if (isUnread)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E3A8A),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Color mapping ─────────────────────────────────────────────────────────────

class _NotifColors {
  const _NotifColors(this.foreground, this.background);

  final Color foreground;
  final Color background;
}

_NotifColors _colorFor(CandidateNotificationType type) {
  return switch (type) {
    CandidateNotificationType.cvAccepted ||
    CandidateNotificationType.shiftAccepted ||
    CandidateNotificationType.shiftConfirmed ||
    CandidateNotificationType.shiftCompleted ||
    CandidateNotificationType.kycApproved => const _NotifColors(
      Color(0xFF16A34A),
      Color(0xFFF0FDF4),
    ),
    CandidateNotificationType.newMessage => const _NotifColors(
      Color(0xFF1E3A8A),
      Color(0xFFEFF6FF),
    ),
    CandidateNotificationType.cvRejected ||
    CandidateNotificationType.paymentFailed ||
    CandidateNotificationType.kycRejected => const _NotifColors(
      Color(0xFFEF4444),
      Color(0xFFFEF2F2),
    ),
    CandidateNotificationType.paymentReleased => const _NotifColors(
      Color(0xFF16A34A),
      Color(0xFFF0FDF4),
    ),
    CandidateNotificationType.profileViewed ||
    CandidateNotificationType.jobRecommended ||
    CandidateNotificationType.system => const _NotifColors(
      Color(0xFF1E3A8A),
      Color(0xFFEFF6FF),
    ),
  };
}

// ── Icon mapping ──────────────────────────────────────────────────────────────

IconData _iconFor(CandidateNotificationType type) {
  return switch (type) {
    CandidateNotificationType.profileViewed => Icons.visibility_outlined,
    CandidateNotificationType.newMessage => Icons.chat_bubble_outline_rounded,
    CandidateNotificationType.cvAccepted ||
    CandidateNotificationType.shiftAccepted ||
    CandidateNotificationType.shiftConfirmed ||
    CandidateNotificationType.shiftCompleted ||
    CandidateNotificationType.paymentReleased ||
    CandidateNotificationType.kycApproved => Icons.check_circle_outline_rounded,
    CandidateNotificationType.cvRejected ||
    CandidateNotificationType.paymentFailed ||
    CandidateNotificationType.kycRejected => Icons.cancel_outlined,
    CandidateNotificationType.jobRecommended => Icons.work_outline_rounded,
    CandidateNotificationType.system => Icons.notifications_none_rounded,
  };
}

// ── Relative time ─────────────────────────────────────────────────────────────

String _relativeTime(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt);
  if (diff.inSeconds < 60) return 'Vừa xong';
  if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
  if (diff.inHours < 24) return '${diff.inHours} giờ trước';
  if (diff.inDays < 7) return '${diff.inDays} ngày trước';
  return '${(diff.inDays / 7).floor()} tuần trước';
}
