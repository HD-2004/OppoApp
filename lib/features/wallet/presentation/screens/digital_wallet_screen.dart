import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../controllers/wallet_controller.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/wallet_balance_card.dart';
import '../widgets/wallet_quick_actions.dart';
import 'transaction_history_screen.dart';
import 'withdraw_funds_screen.dart';

class DigitalWalletScreen extends ConsumerWidget {
  const DigitalWalletScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(walletControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.digitalWallet),
        actions: [
          IconButton(
            tooltip: l10n.retry,
            onPressed: () =>
                ref.read(walletControllerProvider.notifier).refreshWallet(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.text('walletLoadFailed')),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref
                        .read(walletControllerProvider.notifier)
                        .loadWallet(),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
          );
        },
        data: (walletState) {
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(walletControllerProvider.notifier).refreshWallet(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                WalletBalanceCard(
                  wallet: walletState.wallet,
                  isBalanceVisible: walletState.isBalanceVisible,
                  onToggleVisibility: () => ref
                      .read(walletControllerProvider.notifier)
                      .toggleBalanceVisibility(),
                ),
                const SizedBox(height: 16),
                WalletQuickActions(
                  onWithdraw: () => _push(
                    context,
                    WithdrawFundsScreen(
                      wallet: walletState.wallet,
                    ),
                  ),
                  onHistory: () =>
                      _push(context, const TransactionHistoryScreen()),
                ),
                const SizedBox(height: 16),
                RecentTransactionsList(
                  transactions: walletState.recentTransactions,
                  onViewAll: () =>
                      _push(context, const TransactionHistoryScreen()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
