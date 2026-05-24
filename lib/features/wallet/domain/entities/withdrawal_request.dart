import 'wallet_transaction.dart';

class WithdrawalRequest {
  const WithdrawalRequest({
    required this.withdrawalRequestId,
    required this.amount,
    required this.currency,
    required this.bankAccountId,
    required this.bankName,
    required this.accountNumberMasked,
    required this.status,
    required this.requestedAt,
  });

  final String withdrawalRequestId;
  final double amount;
  final String currency;
  final String bankAccountId;
  final String bankName;
  final String accountNumberMasked;
  final WalletTransactionStatus status;
  final DateTime requestedAt;
}
