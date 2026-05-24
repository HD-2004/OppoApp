import '../../domain/entities/wallet_transaction.dart';

class WalletTransactionModel extends WalletTransaction {
  const WalletTransactionModel({
    required super.transactionId,
    required super.type,
    required super.amount,
    required super.currency,
    required super.status,
    required super.description,
    required super.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      transactionId: json['transactionId'] as String,
      type: WalletTransactionType.values.byName(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'VND',
      status: WalletTransactionStatus.values.byName(json['status'] as String),
      description: json['description'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
