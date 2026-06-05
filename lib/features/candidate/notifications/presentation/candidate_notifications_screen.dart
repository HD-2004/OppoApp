import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/notification_controller.dart';
import '../domain/candidate_notification.dart';
import 'widgets/notification_card.dart';
import 'widgets/notification_empty_state.dart';

/// Màn hình thông báo — dùng chung cho toàn bộ app.
/// Dữ liệu từ backend thật: https://iuo7ofruu6.execute-api.ap-southeast-1.amazonaws.com
/// Đồng bộ với website qua cùng REST API + Cognito JWT auth.
class CandidateNotificationsScreen extends ConsumerStatefulWidget {
  const CandidateNotificationsScreen({super.key});

  @override
  ConsumerState<CandidateNotificationsScreen> createState() =>
      _CandidateNotificationsScreenState();
}

class _CandidateNotificationsScreenState
    extends ConsumerState<CandidateNotificationsScreen> {
  // 0 = Tất cả, 1 = Chưa đọc
  int _filterTab = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(candidateNotificationControllerProvider);
    final unreadCount = state.asData?.value.summary.unread ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _NotifAppBar(
        unreadCount: unreadCount,
        onMarkAllRead: unreadCount > 0
            ? () => ref
                  .read(candidateNotificationControllerProvider.notifier)
                  .markAllAsRead()
            : null,
      ),
      body: Column(
        children: [
          // ── Filter tabs: Tất cả | Chưa đọc ───────────────────────────
          _FilterTabBar(
            selectedIndex: _filterTab,
            unreadCount: unreadCount,
            onChanged: (i) => setState(() => _filterTab = i),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // ── Content ───────────────────────────────────────────────────
          Expanded(
            child: state.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => _ErrorState(
                onRetry: () => ref
                    .read(candidateNotificationControllerProvider.notifier)
                    .refreshNotifications(),
              ),
              data: (data) {
                final items = _filterTab == 1
                    ? data.items.where((n) => n.isUnread).toList()
                    : data.items;

                return _NotificationListView(
                  items: items,
                  showUnreadOnly: _filterTab == 1,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────────────────────

class _NotifAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _NotifAppBar({required this.unreadCount, required this.onMarkAllRead});

  final int unreadCount;
  final VoidCallback? onMarkAllRead;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: const BackButton(color: Color(0xFF1E293B)),
      title: Row(
        children: [
          const Text(
            'Thông báo',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (onMarkAllRead != null)
          TextButton(
            onPressed: onMarkAllRead,
            child: const Text(
              'Đọc tất cả',
              style: TextStyle(
                color: Color(0xFF1E3A8A),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ── Filter tab bar ─────────────────────────────────────────────────────────────

class _FilterTabBar extends StatelessWidget {
  const _FilterTabBar({
    required this.selectedIndex,
    required this.unreadCount,
    required this.onChanged,
  });

  final int selectedIndex;
  final int unreadCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _FilterTab(
            label: 'Tất cả',
            isSelected: selectedIndex == 0,
            onTap: () => onChanged(0),
          ),
          const SizedBox(width: 8),
          _FilterTab(
            label: 'Chưa đọc',
            badge: unreadCount > 0 ? unreadCount : null,
            isSelected: selectedIndex == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  const _FilterTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF374151),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── List view ─────────────────────────────────────────────────────────────────

class _NotificationListView extends ConsumerWidget {
  const _NotificationListView({
    required this.items,
    required this.showUnreadOnly,
  });

  final List<CandidateNotification> items;
  final bool showUnreadOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF1E3A8A),
        onRefresh: () => ref
            .read(candidateNotificationControllerProvider.notifier)
            .refreshNotifications(),
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
            NotificationEmptyState(
              message: showUnreadOnly
                  ? 'Không có thông báo chưa đọc'
                  : 'Bạn chưa có thông báo nào',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF1E3A8A),
      onRefresh: () => ref
          .read(candidateNotificationControllerProvider.notifier)
          .refreshNotifications(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return CandidateNotificationCard(
            notification: item,
            onTap: () async {
              // Mark as read ngay khi tap
              if (item.isUnread) {
                await ref
                    .read(candidateNotificationControllerProvider.notifier)
                    .markAsRead(item.id);
              }
              // Deep link navigation nếu có
              if (context.mounted &&
                  item.deepLink != null &&
                  item.deepLink!.startsWith('/')) {
                context.go(item.deepLink!);
              }
            },
            onArchive: () => ref
                .read(candidateNotificationControllerProvider.notifier)
                .archive(item.id),
          );
        },
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 52,
            color: Color(0xFFD1D5DB),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không thể tải thông báo',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kiểm tra kết nối và thử lại.',
            style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Thử lại'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
