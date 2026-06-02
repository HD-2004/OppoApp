import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';

class UserNotificationsScreen extends StatelessWidget {
  const UserNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final l10n = AppLocalizations.of(context);

    // Mock notifications matching the web project
    final notifications = [
      _NotificationItem(
        title: l10n.notificationViewed,
        message: l10n.isVietnamese
            ? 'FPT Software đã xem hồ sơ ứng tuyển Senior React Developer của bạn'
            : 'FPT Software viewed your Senior React Developer application',
        time: l10n.isVietnamese ? '2 giờ trước' : '2 hours ago',
        icon: Icons.visibility,
        iconColor: const Color(0xFF1E40AF),
        bgColor: const Color(0xFFEFF6FF),
      ),
      _NotificationItem(
        title: l10n.notificationMessage,
        message: l10n.isVietnamese
            ? 'Bạn có tin nhắn mới từ Hồng Trà Ngô Gia'
            : 'You have a new message from Hong Tra Ngo Gia',
        time: l10n.isVietnamese ? '5 giờ trước' : '5 hours ago',
        icon: Icons.chat_bubble_outline,
        iconColor: const Color(0xFFEA580C),
        bgColor: const Color(0xFFFFF7ED),
      ),
      _NotificationItem(
        title: l10n.notificationAccepted,
        message: l10n.isVietnamese
            ? 'Hồ sơ Nhân viên tại Highlands của bạn đã được chấp nhận'
            : 'Your Highlands Employee application has been accepted',
        time: l10n.isVietnamese ? '1 ngày trước' : '1 day ago',
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xFF16A34A),
        bgColor: const Color(0xFFF0FDF4),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.notifications,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    l10n.isVietnamese
                        ? 'Đã đánh dấu tất cả là đã đọc'
                        : 'Marked all as read',
                  ),
                ),
              );
            },
            child: Text(
              l10n.isVietnamese ? 'Đọc tất cả' : 'Read all',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notifications.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = notifications[index];
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
                    color: item.bgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: item.iconColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    color: item.iconColor,
                    size: 24,
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.title,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          item.time,
                          style: textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.message,
                      style: textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(item.title)),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
  });

  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
}
