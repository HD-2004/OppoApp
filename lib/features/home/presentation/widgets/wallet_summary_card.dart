import 'package:flutter/material.dart';

import 'package:oppo_temp_jobs/core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../features/wallet/presentation/controllers/wallet_controller.dart';

class WalletSummaryCard extends ConsumerWidget {
  const WalletSummaryCard({super.key, required this.onWithdrawTap});

  final VoidCallback onWithdrawTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletControllerProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: walletAsync.when(
        loading: () => const _WalletCardSkeleton(),
        error: (_, _) => _WalletCardContent(
          balance: null,
          canWithdraw: false,
          onWithdrawTap: onWithdrawTap,
        ),
        data: (state) => _WalletCardContent(
          balance: state.wallet.availableBalance,
          canWithdraw:
              state.wallet.isActive && state.wallet.availableBalance > 0,
          onWithdrawTap: onWithdrawTap,
        ),
      ),
    );
  }
}

class _WalletCardContent extends StatelessWidget {
  const _WalletCardContent({
    required this.balance,
    required this.canWithdraw,
    required this.onWithdrawTap,
  });

  final double? balance;
  final bool canWithdraw;
  final VoidCallback onWithdrawTap;

  String _formatBalance(double? value) {
    if (value == null) return '—';
    final formatter = NumberFormat('#,###', 'vi_VN');
    return '${formatter.format(value)}đ';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.secondary, Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Ví của tôi',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatBalance(balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          // Withdraw button
          GestureDetector(
            onTap: canWithdraw ? onWithdrawTap : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Rút tiền',
                    style: TextStyle(
                      color: canWithdraw
                          ? AppColors.secondary
                          : const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: canWithdraw
                        ? AppColors.secondary
                        : const Color(0xFF9CA3AF),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletCardSkeleton extends StatelessWidget {
  const _WalletCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
      ),
    );
  }
}
