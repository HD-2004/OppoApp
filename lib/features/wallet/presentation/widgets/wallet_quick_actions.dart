import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class WalletQuickActions extends StatelessWidget {
  const WalletQuickActions({
    super.key,
    required this.onWithdraw,
    required this.onLinkBank,
    required this.onHistory,
    required this.onStatistics,
  });

  final VoidCallback onWithdraw;
  final VoidCallback onLinkBank;
  final VoidCallback onHistory;
  final VoidCallback onStatistics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _ActionTile(
          icon: Icons.payments_outlined,
          label: l10n.text('withdraw'),
          onTap: onWithdraw,
        ),
        _ActionTile(
          icon: Icons.account_balance_outlined,
          label: l10n.text('linkBank'),
          onTap: onLinkBank,
        ),
        _ActionTile(
          icon: Icons.receipt_long_outlined,
          label: l10n.text('transactionHistory'),
          onTap: onHistory,
        ),
        _ActionTile(
          icon: Icons.bar_chart_outlined,
          label: l10n.text('revenueStatistics'),
          onTap: onStatistics,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
