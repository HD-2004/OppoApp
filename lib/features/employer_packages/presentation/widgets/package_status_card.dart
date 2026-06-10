import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/featured_employer_package_providers.dart';
import '../../domain/employer_package.dart';
import 'package_badge.dart';

class PackageStatusCard extends ConsumerWidget {
  const PackageStatusCard({super.key, required this.onRenew});

  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(currentPackageStatusProvider);

    return statusAsync.when(
      loading: () => const _PackageStatusSkeleton(),
      error: (_, _) => _PackageStatusEmpty(
        onAction: () => ref.invalidate(currentPackageStatusProvider),
        actionLabel: 'Thử lại',
      ),
      data: (status) {
        if (status == null) {
          return _PackageStatusEmpty(onAction: onRenew);
        }
        return _PackageStatusContent(status: status, onRenew: onRenew);
      },
    );
  }
}

class _PackageStatusContent extends StatelessWidget {
  const _PackageStatusContent({required this.status, required this.onRenew});

  final EmployerPackageStatus status;
  final VoidCallback? onRenew;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final colorScheme = Theme.of(context).colorScheme;
    final formatter = DateFormat('dd/MM/yyyy');
    final remainingDays = status.remainingDays(now);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gói hiện tại',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PackageBadge(tier: status.tier),
            ],
          ),
          const SizedBox(height: 14),
          _StatusRow(
            label: 'Ngày kích hoạt',
            value: formatter.format(status.activatedAt),
          ),
          const SizedBox(height: 8),
          _StatusRow(
            label: 'Ngày hết hạn',
            value: formatter.format(status.expiresAt),
          ),
          const SizedBox(height: 8),
          _StatusRow(label: 'Còn lại', value: '$remainingDays ngày'),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: status.progress(now),
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                status.tier.accentColor,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: onRenew,
              child: const Text('Gia hạn'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _PackageStatusEmpty extends StatelessWidget {
  const _PackageStatusEmpty({this.onAction, this.actionLabel = 'Xem gói'});

  final VoidCallback? onAction;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.workspace_premium_outlined,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          const Expanded(child: Text('Bạn chưa đăng ký gói hiển thị')),
          if (onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _PackageStatusSkeleton extends StatelessWidget {
  const _PackageStatusSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
