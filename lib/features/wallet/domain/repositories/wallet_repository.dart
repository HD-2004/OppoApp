import '../entities/linked_bank_account.dart';
import '../entities/revenue_statistics.dart';
import '../entities/wallet.dart';
import '../entities/wallet_transaction.dart';
import '../entities/withdrawal_request.dart';

abstract interface class WalletRepository {
  Future<WalletOverview> getWalletOverview();

  Future<List<WalletTransaction>> getTransactions({
    WalletTransactionType? type,
    WalletTransactionStatus? status,
  });

  Future<LinkedBankAccount?> getLinkedBankAccount();

  Future<LinkedBankAccount> linkBankAccount({
    required String bankName,
    required String accountHolderName,
    required String accountNumber,
    String? branch,
  });

  Future<void> removeBankAccount({required String bankAccountId});

  Future<WithdrawalRequest> createWithdrawalRequest({
    required double amount,
    required String bankAccountId,
  });

  Future<RevenueStatistics> getRevenueStatistics();
}
