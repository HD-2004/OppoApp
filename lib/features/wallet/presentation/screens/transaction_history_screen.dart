import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../controllers/wallet_controller.dart';
import '../widgets/transaction_list_tile.dart';

enum _TransactionFilter { all, earnings, withdrawals, failed }

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  _TransactionFilter _selectedFilter = _TransactionFilter.all;

  List<WalletTransaction> _filtered(List<WalletTransaction> transactions) {
    return switch (_selectedFilter) {
      _TransactionFilter.all => transactions,
      _TransactionFilter.earnings =>
        transactions
            .where((item) => item.type == WalletTransactionType.earning)
            .toList(),
      _TransactionFilter.withdrawals =>
        transactions
            .where((item) => item.type == WalletTransactionType.withdrawal)
            .toList(),
      _TransactionFilter.failed =>
        transactions
            .where((item) => item.status == WalletTransactionStatus.failed)
            .toList(),
    };
  }

  String _label(AppLocalizations l10n, _TransactionFilter filter) {
    return switch (filter) {
      _TransactionFilter.all => l10n.text('all'),
      _TransactionFilter.earnings => l10n.text('earnings'),
      _TransactionFilter.withdrawals => l10n.text('withdrawals'),
      _TransactionFilter.failed => l10n.text('failed'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(walletControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('transactionHistory'))),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text(l10n.text('walletLoadFailed'))),
          data: (walletState) {
            final transactions = _filtered(walletState.transactions);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in _TransactionFilter.values) ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            selected: _selectedFilter == filter,
                            label: Text(_label(l10n, filter)),
                            onSelected: (_) {
                              setState(() => _selectedFilter = filter);
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (transactions.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: Text(l10n.text('noTransactions'))),
                    ),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          for (final transaction in transactions)
                            TransactionListTile(transaction: transaction),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
