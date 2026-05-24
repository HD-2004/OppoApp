import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/wallet.dart';
import 'wallet_formatters.dart';

class WalletBalanceCard extends StatelessWidget {
  const WalletBalanceCard({
    super.key,
    required this.wallet,
    required this.isBalanceVisible,
    required this.onToggleVisibility,
  });

  final WalletOverview wallet;
  final bool isBalanceVisible;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final hidden = !isBalanceVisible;

    return Card(
      color: theme.colorScheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.text('availableBalance'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: hidden
                      ? l10n.text('showBalance')
                      : l10n.text('hideBalance'),
                  onPressed: onToggleVisibility,
                  icon: Icon(
                    hidden ? Icons.visibility_outlined : Icons.visibility_off,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatVnd(wallet.availableBalance, hidden: hidden),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _BalanceMetric(
                    label: l10n.text('pendingBalance'),
                    value: formatVnd(wallet.pendingBalance, hidden: hidden),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _BalanceMetric(
                    label: l10n.text('totalEarnings'),
                    value: formatVnd(wallet.totalEarnings, hidden: hidden),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceMetric extends StatelessWidget {
  const _BalanceMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.78),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
