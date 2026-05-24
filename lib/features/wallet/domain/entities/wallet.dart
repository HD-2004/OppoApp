enum WalletStatus { active, frozen }

class WalletOverview {
  const WalletOverview({
    required this.availableBalance,
    required this.pendingBalance,
    required this.totalEarnings,
    required this.currency,
    required this.status,
  });

  final double availableBalance;
  final double pendingBalance;
  final double totalEarnings;
  final String currency;
  final WalletStatus status;

  bool get isActive => status == WalletStatus.active;

  WalletOverview copyWith({
    double? availableBalance,
    double? pendingBalance,
    double? totalEarnings,
    String? currency,
    WalletStatus? status,
  }) {
    return WalletOverview(
      availableBalance: availableBalance ?? this.availableBalance,
      pendingBalance: pendingBalance ?? this.pendingBalance,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      currency: currency ?? this.currency,
      status: status ?? this.status,
    );
  }
}
