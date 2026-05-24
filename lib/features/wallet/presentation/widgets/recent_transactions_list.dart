import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/wallet_transaction.dart';
import 'transaction_list_tile.dart';

class RecentTransactionsList extends StatelessWidget {
  const RecentTransactionsList({
    super.key,
    required this.transactions,
    required this.onViewAll,
  });

  final List<WalletTransaction> transactions;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.text('recentTransactions'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: Text(l10n.text('viewAll')),
                ),
              ],
            ),
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n.text('noTransactions')),
              )
            else
              for (final transaction in transactions)
                TransactionListTile(transaction: transaction),
          ],
        ),
      ),
    );
  }
}
