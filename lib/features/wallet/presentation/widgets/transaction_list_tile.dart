import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/wallet_transaction.dart';
import 'wallet_formatters.dart';

class TransactionListTile extends StatelessWidget {
  const TransactionListTile({super.key, required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isCredit = transaction.amount >= 0;
    final amountPrefix = isCredit ? '+' : '-';
    final amount = formatVnd(transaction.amount.abs());

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(_iconForType(transaction.type))),
      title: Text(transaction.description),
      subtitle: Text(
        '${_statusLabel(l10n, transaction.status)} • ${DateFormat('dd/MM/yyyy').format(transaction.createdAt)}',
      ),
      trailing: Text(
        '$amountPrefix$amount',
        style: TextStyle(
          color: isCredit
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  IconData _iconForType(WalletTransactionType type) {
    return switch (type) {
      WalletTransactionType.earning => Icons.add_card,
      WalletTransactionType.withdrawal => Icons.payments_outlined,
      WalletTransactionType.refund => Icons.undo,
      WalletTransactionType.adjustment => Icons.tune,
    };
  }

  String _statusLabel(AppLocalizations l10n, WalletTransactionStatus status) {
    return switch (status) {
      WalletTransactionStatus.pending => l10n.text('transactionPending'),
      WalletTransactionStatus.processing => l10n.text('transactionProcessing'),
      WalletTransactionStatus.completed => l10n.text('transactionCompleted'),
      WalletTransactionStatus.failed => l10n.text('transactionFailed'),
      WalletTransactionStatus.cancelled => l10n.text('transactionCancelled'),
    };
  }
}
