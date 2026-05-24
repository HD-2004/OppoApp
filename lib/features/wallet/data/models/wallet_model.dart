import '../../domain/entities/wallet.dart';

class WalletModel extends WalletOverview {
  const WalletModel({
    required super.availableBalance,
    required super.pendingBalance,
    required super.totalEarnings,
    required super.currency,
    required super.status,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      availableBalance: (json['availableBalance'] as num).toDouble(),
      pendingBalance: (json['pendingBalance'] as num).toDouble(),
      totalEarnings: (json['totalEarnings'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'VND',
      status: json['status'] == 'frozen'
          ? WalletStatus.frozen
          : WalletStatus.active,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'availableBalance': availableBalance,
      'pendingBalance': pendingBalance,
      'totalEarnings': totalEarnings,
      'currency': currency,
      'status': status.name,
    };
  }
}
