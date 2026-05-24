import '../../domain/entities/linked_bank_account.dart';
import '../../domain/entities/revenue_statistics.dart';
import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_transaction.dart';
import '../../domain/entities/withdrawal_request.dart';
import '../../domain/repositories/wallet_repository.dart';

class ApiWalletRepository implements WalletRepository {
  const ApiWalletRepository();

  // TODO: Inject authenticated API client here.
  // TODO: Attach Cognito access token in Authorization header.
  // TODO: Never trust userId from Flutter body; backend must read Cognito claims.

  @override
  Future<WalletOverview> getWalletOverview() {
    // TODO: GET /wallet
    throw UnimplementedError('Connect GET /wallet via API Gateway or AppSync.');
  }

  @override
  Future<List<WalletTransaction>> getTransactions({
    WalletTransactionType? type,
    WalletTransactionStatus? status,
  }) {
    // TODO: GET /wallet/transactions?type=&status=
    throw UnimplementedError('Connect GET /wallet/transactions.');
  }

  @override
  Future<LinkedBankAccount?> getLinkedBankAccount() {
    // TODO: GET /wallet, read linkedBankAccount from response.
    throw UnimplementedError('Connect linked bank account API.');
  }

  @override
  Future<LinkedBankAccount> linkBankAccount({
    required String bankName,
    required String accountHolderName,
    required String accountNumber,
    String? branch,
  }) {
    // TODO: POST /wallet/bank-accounts
    throw UnimplementedError('Connect POST /wallet/bank-accounts.');
  }

  @override
  Future<void> removeBankAccount({required String bankAccountId}) {
    // TODO: DELETE /wallet/bank-accounts/{bankAccountId}
    throw UnimplementedError('Connect DELETE /wallet/bank-accounts/{id}.');
  }

  @override
  Future<WithdrawalRequest> createWithdrawalRequest({
    required double amount,
    required String bankAccountId,
  }) {
    // TODO: POST /wallet/withdrawals
    throw UnimplementedError('Connect POST /wallet/withdrawals.');
  }

  @override
  Future<RevenueStatistics> getRevenueStatistics() {
    // TODO: GET /wallet/statistics
    throw UnimplementedError('Connect GET /wallet/statistics.');
  }
}
