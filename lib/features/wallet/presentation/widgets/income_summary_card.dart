import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/revenue_statistics.dart';
import 'wallet_formatters.dart';

class IncomeSummaryCard extends StatelessWidget {
  const IncomeSummaryCard({super.key, required this.statistics});

  final RevenueStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.text('incomeSummary'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: l10n.text('thisWeekIncome'),
                    value: formatVnd(statistics.thisWeekIncome),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: l10n.text('thisMonthIncome'),
                    value: formatVnd(statistics.thisMonthIncome),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: l10n.text('completedShifts'),
                    value: '${statistics.completedShifts}',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: l10n.text('averageIncomePerShift'),
                    value: formatVnd(statistics.averageIncomePerShift),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
