import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/featured_employer_package_providers.dart';
import '../../domain/employer_package.dart';
import '../widgets/package_badge.dart';

class PackageComparisonScreen extends ConsumerStatefulWidget {
  const PackageComparisonScreen({super.key});

  @override
  ConsumerState<PackageComparisonScreen> createState() =>
      _PackageComparisonScreenState();
}

class _PackageComparisonScreenState
    extends ConsumerState<PackageComparisonScreen> {
  EmployerPackagePlan? _selectedPlan;
  _PurchaseStep _step = _PurchaseStep.select;

  Future<void> _purchaseSelectedPlan() async {
    final plan = _selectedPlan;
    if (plan == null) return;

    await ref
        .read(packagePurchaseControllerProvider.notifier)
        .purchase(plan.tier);

    final purchaseState = ref.read(packagePurchaseControllerProvider);
    if (!mounted) return;

    if (purchaseState.hasError) {
      final message = purchaseState.error.toString().replaceAll(
        'Unsupported operation: ',
        '',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    setState(() => _step = _PurchaseStep.success);
  }

  void _resetFlow() {
    setState(() {
      _selectedPlan = null;
      _step = _PurchaseStep.select;
    });
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(packagePlansProvider);
    final purchaseState = ref.watch(packagePurchaseControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Packages')),
      body: SafeArea(
        child: plansAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _PackagePlansEmpty(
            onRetry: () => ref.invalidate(packagePlansProvider),
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return const _PackagePlansEmpty();
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _FlowHeader(step: _step),
                const SizedBox(height: 16),
                if (_step == _PurchaseStep.select)
                  ...plans.map(
                    (plan) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PackagePlanCard(
                        plan: plan,
                        onBuy: () {
                          setState(() {
                            _selectedPlan = plan;
                            _step = _PurchaseStep.confirm;
                          });
                        },
                      ),
                    ),
                  )
                else if (_step == _PurchaseStep.confirm)
                  _ConfirmStep(
                    plan: _selectedPlan!,
                    onBack: _resetFlow,
                    onContinue: () {
                      setState(() => _step = _PurchaseStep.payment);
                    },
                  )
                else if (_step == _PurchaseStep.payment)
                  _PaymentStep(
                    plan: _selectedPlan!,
                    isLoading: purchaseState.isLoading,
                    onBack: () {
                      setState(() => _step = _PurchaseStep.confirm);
                    },
                    onPay: _purchaseSelectedPlan,
                  )
                else
                  _SuccessStep(onDone: _resetFlow),
              ],
            );
          },
        ),
      ),
    );
  }
}

enum _PurchaseStep { select, confirm, payment, success }

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({required this.step});

  final _PurchaseStep step;

  @override
  Widget build(BuildContext context) {
    final labels = const ['Select Package', 'Confirm', 'Payment', 'Success'];
    final activeIndex = _PurchaseStep.values.indexOf(step);

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: i <= activeIndex
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i <= activeIndex
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          if (i < labels.length - 1)
            Container(
              width: 18,
              height: 2,
              color: i < activeIndex
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
        ],
      ],
    );
  }
}

class _PackagePlanCard extends StatelessWidget {
  const _PackagePlanCard({required this.plan, required this.onBuy});

  final EmployerPackagePlan plan;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: plan.tier.accentColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: PackageBadge(tier: plan.tier)),
              if (plan.priceLabel?.isNotEmpty == true)
                Text(
                  plan.priceLabel!,
                  style: TextStyle(
                    color: plan.tier.accentColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          if (plan.description?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Text(
              plan.description!,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          ...plan.benefits.map(
            (benefit) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: plan.tier.accentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(benefit)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onBuy, child: const Text('Mua gói')),
          ),
        ],
      ),
    );
  }
}

class _ConfirmStep extends StatelessWidget {
  const _ConfirmStep({
    required this.plan,
    required this.onBack,
    required this.onContinue,
  });

  final EmployerPackagePlan plan;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _FlowPanel(
      title: 'Xác nhận gói',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PackageBadge(tier: plan.tier),
          const SizedBox(height: 12),
          Text('Bạn đang chọn gói ${plan.tier.title}.'),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  child: const Text('Quay lại'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onContinue,
                  child: const Text('Tiếp tục'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentStep extends StatelessWidget {
  const _PaymentStep({
    required this.plan,
    required this.isLoading,
    required this.onBack,
    required this.onPay,
  });

  final EmployerPackagePlan plan;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return _FlowPanel(
      title: 'Thanh toán',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gói: ${plan.tier.title}'),
          if (plan.priceLabel?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text('Chi phí: ${plan.priceLabel}'),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : onBack,
                  child: const Text('Quay lại'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: isLoading ? null : onPay,
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Thanh toán'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return _FlowPanel(
      title: 'Thanh toán thành công',
      child: Column(
        children: [
          Icon(
            Icons.verified_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Trạng thái gói và dashboard đã được làm mới.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onDone,
              child: const Text('Hoàn tất'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowPanel extends StatelessWidget {
  const _FlowPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PackagePlansEmpty extends StatelessWidget {
  const _PackagePlansEmpty({this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 46,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text(
              'Bạn chưa đăng ký gói hiển thị',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Chưa có gói khả dụng để mua.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ],
        ),
      ),
    );
  }
}
