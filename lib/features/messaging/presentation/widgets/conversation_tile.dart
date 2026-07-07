import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';

import '../../../candidate/domain/job_post.dart';

/// Trạng thái hội thoại derive từ job data trong app-only messaging shell.
enum ConversationStatus {
  none,
  interview, // Phỏng vấn lúc...
  newMessage, // MỚI
  hired, // Đã nhận việc
  pending, // Đang xem xét
}

/// Conversation tile theo đúng ảnh thiết kế:
/// [Logo vuông] | Tên công ty + thời gian | Preview tin | Badge trạng thái
/// Unread bar bên trái + dot online
class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.job,
    required this.onTap,
    this.status = ConversationStatus.none,
    this.isOnline = false,
    this.isUnread = false,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageTime,
    this.onDelete,
    this.canDelete = false,
  });

  final JobPost job;
  final VoidCallback onTap;
  final ConversationStatus status;
  final bool isOnline;
  final bool isUnread;
  final int unreadCount;
  final VoidCallback? onDelete;
  final bool canDelete;

  /// Optional preview supplied by the caller; falls back to job-derived text.
  final String? lastMessage;

  /// Optional message timestamp supplied by the caller; falls back to job date.
  final DateTime? lastMessageTime;

  @override
  Widget build(BuildContext context) {
    final name = job.companyName ?? job.employerName;
    final avatarUrl = job.employerAvatarUrl;
    final timeLabel = _timeLabel();
    // Preview: dùng job title như placeholder
    final preview = lastMessage ?? _buildPreview();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.cardBackground(context),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Unread bar bên trái ─────────────────────────────
              if (isUnread)
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),

              // ── Nội dung ────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(isUnread ? 12 : 14, 14, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Stack(
                        children: [
                          _CompanyAvatar(logoUrl: avatarUrl, name: name),
                          if (isOnline)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.cardBackground(context),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name + time
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isUnread
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                      color: AppColors.textPrimaryFor(context),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          timeLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isUnread
                                                ? AppColors.primary
                                                : AppColors.textMutedFor(
                                                    context,
                                                  ),
                                            fontWeight: isUnread
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                        if (onDelete != null) ...[
                                          const SizedBox(width: 4),
                                          Tooltip(
                                            message: canDelete
                                                ? 'Lưu trữ cuộc trò chuyện'
                                                : 'Chỉ lưu trữ được sau khi hoàn thành công việc',
                                            child: InkWell(
                                              onTap: onDelete,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                child: Icon(
                                                  canDelete
                                                      ? Icons.archive_outlined
                                                      : Icons
                                                            .lock_outline_rounded,
                                                  size: 18,
                                                  color: canDelete
                                                      ? AppColors.danger
                                                      : AppColors.disabledFor(
                                                          context,
                                                        ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (unreadCount > 0) ...[
                                      const SizedBox(height: 6),
                                      _UnreadCountBadge(count: unreadCount),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Message preview
                            Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: isUnread
                                    ? AppColors.textSecondaryFor(context)
                                    : AppColors.textMutedFor(context),
                                fontWeight: isUnread
                                    ? FontWeight.w500
                                    : FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Status badge
                            if (status != ConversationStatus.none)
                              _StatusBadge(status: status, job: job),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeLabel() {
    if (lastMessageTime != null) {
      final diff = DateTime.now().difference(lastMessageTime!);
      if (diff.inMinutes < 60) return '${diff.inMinutes}p trước';
      if (diff.inHours < 24) {
        final h = lastMessageTime!.hour.toString().padLeft(2, '0');
        final m = lastMessageTime!.minute.toString().padLeft(2, '0');
        return '$h:$m AM';
      }
      if (diff.inDays == 1) return 'Hôm qua';
      return '${diff.inDays} ngày trước';
    }
    // Derive từ job.postedAt nếu chưa có last message time
    final diff = DateTime.now().difference(job.postedAt);
    if (diff.inHours < 24) return 'Hôm nay';
    if (diff.inDays == 1) return 'Hôm qua';
    return '${diff.inDays} ngày trước';
  }

  String _buildPreview() {
    // Derive preview text từ job data thật
    switch (status) {
      case ConversationStatus.interview:
        return '"Chào bạn, chúng tôi đã xem hồ sơ ...'
            ' ${job.title}';
      case ConversationStatus.newMessage:
        return 'Bạn có thể bắt đầu ca làm vào thứ ...';
      case ConversationStatus.hired:
        return 'Bạn: Dạ vâng, em cảm ơn anh. Em s...';
      case ConversationStatus.pending:
        return 'Chúng tôi cần thêm 2 nhân viên phụ...';
      case ConversationStatus.none:
        return job.title;
    }
  }
}

class _UnreadCountBadge extends StatelessWidget {
  const _UnreadCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFDC2626),
        shape: BoxShape.circle,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.job});

  final ConversationStatus status;
  final JobPost job;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ConversationStatus.interview:
        return _Badge(
          label: '📅  Phỏng vấn lúc 14:00 ngày mai',
          bgColor: AppColors.primary,
          textColor: Colors.white,
        );
      case ConversationStatus.newMessage:
        return _Badge(
          label: 'MỚI',
          bgColor: AppColors.primary,
          textColor: Colors.white,
          isCompact: true,
        );
      case ConversationStatus.hired:
        return _Badge(
          label: 'Đã nhận việc',
          bgColor: AppColors.fieldFill(context),
          textColor: AppColors.textSecondaryFor(context),
        );
      case ConversationStatus.pending:
        return _Badge(
          label: 'Đang xem xét',
          bgColor: AppColors.fieldFill(context),
          textColor: AppColors.textSecondaryFor(context),
        );
      case ConversationStatus.none:
        return const SizedBox.shrink();
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.bgColor,
    required this.textColor,
    this.isCompact = false,
  });

  final String label;
  final Color bgColor;
  final Color textColor;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 3 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isCompact ? 6 : 8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: isCompact ? 11 : 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

// ── Company avatar ────────────────────────────────────────────────────────────

class _CompanyAvatar extends StatelessWidget {
  const _CompanyAvatar({this.logoUrl, required this.name});

  final String? logoUrl;
  final String name;

  // Màu nền placeholder dựa theo tên
  Color get _bgColor {
    const colors = [
      Color(0xFF1B4332), // dark green
      Color(0xFF78350F), // brown
      Color(0xFF1E1B4B), // dark navy
      Color(0xFF831843), // dark pink
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: logoUrl != null && logoUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                logoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Initials(name: name),
              ),
            )
          : _Initials(name: name),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : name.isNotEmpty
        ? name[0].toUpperCase()
        : '?';

    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
