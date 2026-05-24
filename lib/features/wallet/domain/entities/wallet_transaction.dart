enum WalletTransactionType { earning, withdrawal, refund, adjustment }

enum WalletTransactionStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
}

class WalletTransaction {
  const WalletTransaction({
    required this.transactionId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.description,
    required this.createdAt,
  });

  final String transactionId;
  final WalletTransactionType type;
  final double amount;
  final String currency;
  final WalletTransactionStatus status;
  final String description;
  final DateTime createdAt;

  bool get isCredit {
    return type == WalletTransactionType.earning ||
        type == WalletTransactionType.refund ||
        type == WalletTransactionType.adjustment && amount >= 0;
  }
}
