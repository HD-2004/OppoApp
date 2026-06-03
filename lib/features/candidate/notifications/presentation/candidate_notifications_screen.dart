import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../application/notification_controller.dart';
import '../domain/notification_repository.dart';
import 'widgets/notification_card.dart';
import 'widgets/notification_empty_state.dart';

class CandidateNotificationsScreen extends ConsumerWidget {
  const CandidateNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = AppLocalizations.of(context);
    final state = ref.watch(candidateNotificationControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.notifications,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: state.maybeWhen(
              data: (data) => data.summary.unread == 0
                  ? null
                  : () => ref
                      .read(candidateNotificationControllerProvider.notifier)
                      .markAllAsRead(),
              orElse: () => null,
            ),
            child: Text(
              strings.isVietnamese ? 'Đọc tất cả' : 'Read all',
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
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => RefreshIndicator(
            onRefresh: () => ref
                .read(candidateNotificationControllerProvider.notifier)
                .refreshNotifications(),
            child: ListView(
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                NotificationEmptyState(
                  message: strings.isVietnamese
                      ? 'Không thể tải thông báo'
                      : 'Unable to load notifications',
                ),
              ],
            ),
          ),
          data: (data) => _NotificationList(data: data),
        ),
      ),
    );
  }
}

class _NotificationList extends ConsumerWidget {
  const _NotificationList({required this.data});

  final CandidateNotificationList data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppLocalizations.of(context);
    if (data.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref
            .read(candidateNotificationControllerProvider.notifier)
            .refreshNotifications(),
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
            NotificationEmptyState(
              message: strings.isVietnamese
                  ? 'Bạn chưa có thông báo nào'
                  : 'You do not have any notifications yet',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref
          .read(candidateNotificationControllerProvider.notifier)
          .refreshNotifications(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: data.items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final item = data.items[index];
          return CandidateNotificationCard(
            notification: item,
            onTap: () async {
              await ref
                  .read(candidateNotificationControllerProvider.notifier)
                  .markAsRead(item.id);
              if (context.mounted &&
                  item.deepLink != null &&
                  item.deepLink!.startsWith('/')) {
                context.go(item.deepLink!);
              }
            },
          );
        },
      ),
    );
  }
}
