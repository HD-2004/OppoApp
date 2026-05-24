import '../../domain/entities/wallet_transaction.dart';
import '../../domain/entities/withdrawal_request.dart';

class WithdrawalRequestModel extends WithdrawalRequest {
  const WithdrawalRequestModel({
    required super.withdrawalRequestId,
    required super.amount,
    required super.currency,
    required super.bankAccountId,
    required super.bankName,
    required super.accountNumberMasked,
    required super.status,
    required super.requestedAt,
  });

  factory WithdrawalRequestModel.fromJson(Map<String, dynamic> json) {
    return WithdrawalRequestModel(
      withdrawalRequestId: json['withdrawalRequestId'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'VND',
      bankAccountId: json['bankAccountId'] as String,
      bankName: json['bankName'] as String,
      accountNumberMasked: json['accountNumberMasked'] as String,
      status: WalletTransactionStatus.values.byName(json['status'] as String),
      requestedAt: DateTime.parse(json['requestedAt'] as String),
    );
  }
}
