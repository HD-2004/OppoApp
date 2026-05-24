import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../controllers/wallet_controller.dart';
import '../widgets/income_summary_card.dart';
import '../widgets/wallet_formatters.dart';

class RevenueStatisticsScreen extends ConsumerWidget {
  const RevenueStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(walletControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.text('revenueStatistics'))),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              Center(child: Text(l10n.text('walletLoadFailed'))),
          data: (walletState) {
            final statistics = walletState.statistics;
            final monthlyItems = [
              _MonthlyIncome(l10n.text('thisMonthIncome'), 1.0),
              _MonthlyIncome(l10n.text('thisWeekIncome'), 0.18),
            ];

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                IncomeSummaryCard(statistics: statistics),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.text('revenueStatistics'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 16),
                        for (final item in monthlyItems) ...[
                          Text(item.label),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(value: item.value),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          '${l10n.text('averageIncomePerShift')}: '
                          '${formatVnd(statistics.averageIncomePerShift)}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MonthlyIncome {
  const _MonthlyIncome(this.label, this.value);

  final String label;
  final double value;
}
