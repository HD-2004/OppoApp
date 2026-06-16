import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/api_wallet_repository.dart';
import '../../domain/entities/linked_bank_account.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/entities/withdrawal_request.dart';
import '../../domain/repositories/wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return ApiWalletRepository();
});

final walletControllerProvider =
    AsyncNotifierProvider<WalletController, WalletState>(WalletController.new);

class WalletState {
  const WalletState({
    required this.wallet,
    required this.recentTransactions,
    required this.transactions,
    this.linkedBankAccount,
    this.isBalanceVisible = true,
    this.isRefreshing = false,
    this.errorMessage,
  });

  final WalletOverview wallet;
  final LinkedBankAccount? linkedBankAccount;
  final List<WalletTransaction> recentTransactions;
  final List<WalletTransaction> transactions;
  final bool isBalanceVisible;
  final bool isRefreshing;
  final String? errorMessage;

  WalletState copyWith({
    WalletOverview? wallet,
    LinkedBankAccount? linkedBankAccount,
    bool clearLinkedBankAccount = false,
    List<WalletTransaction>? recentTransactions,
    List<WalletTransaction>? transactions,
    bool? isBalanceVisible,
    bool? isRefreshing,
    String? errorMessage,
  }) {
    return WalletState(
      wallet: wallet ?? this.wallet,
      linkedBankAccount: clearLinkedBankAccount
          ? null
          : linkedBankAccount ?? this.linkedBankAccount,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      transactions: transactions ?? this.transactions,
      isBalanceVisible: isBalanceVisible ?? this.isBalanceVisible,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage,
    );
  }
}

class WalletController extends AsyncNotifier<WalletState> {
  WalletRepository get _repository => ref.read(walletRepositoryProvider);

  @override
  Future<WalletState> build() async {
    return _load();
  }

  Future<WalletState> _load() async {
    final wallet = await _repository.getWalletOverview();
    final bankAccount = await _repository.getLinkedBankAccount();
    final transactions = await _repository.getTransactions();
    return WalletState(
      wallet: wallet,
      linkedBankAccount: bankAccount,
      recentTransactions: transactions.take(5).toList(),
      transactions: transactions,
    );
  }

  Future<void> loadWallet() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> refreshWallet() async {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(isRefreshing: true));
    }
    state = await AsyncValue.guard(_load);
  }

  Future<void> loadTransactions({
    WalletTransactionType? type,
    WalletTransactionStatus? status,
  }) async {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    final transactions = await _repository.getTransactions(
      type: type,
      status: status,
    );
    state = AsyncData(
      current.copyWith(
        transactions: transactions,
        recentTransactions: transactions.take(5).toList(),
      ),
    );
  }

  Future<LinkedBankAccount> linkBankAccount({
    required String bankName,
    required String accountHolderName,
    required String accountNumber,
    String? branch,
  }) async {
    final account = await _repository.linkBankAccount(
      bankName: bankName,
      accountHolderName: accountHolderName,
      accountNumber: accountNumber,
      branch: branch,
    );
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(linkedBankAccount: account));
    }
    return account;
  }

  Future<void> removeBankAccount({required String bankAccountId}) async {
    await _repository.removeBankAccount(bankAccountId: bankAccountId);
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(current.copyWith(clearLinkedBankAccount: true));
    }
  }

  Future<WithdrawalRequest> createWithdrawalRequest({
    required double amount,
    required String bankName,
    required String accountNumber,
    required String accountHolderName,
    String? branch,
  }) async {
    final request = await _repository.createWithdrawalRequest(
      amount: amount,
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolderName: accountHolderName,
      branch: branch,
    );
    await refreshWallet();
    return request;
  }

  void toggleBalanceVisibility() {
    final current = state.asData?.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(isBalanceVisible: !current.isBalanceVisible),
    );
  }
}
