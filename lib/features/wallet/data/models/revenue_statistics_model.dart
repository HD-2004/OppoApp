import '../../domain/entities/revenue_statistics.dart';

class RevenueStatisticsModel extends RevenueStatistics {
  const RevenueStatisticsModel({
    required super.thisWeekIncome,
    required super.thisMonthIncome,
    required super.completedShifts,
    required super.averageIncomePerShift,
  });

  factory RevenueStatisticsModel.fromJson(Map<String, dynamic> json) {
    return RevenueStatisticsModel(
      thisWeekIncome: (json['thisWeekIncome'] as num).toDouble(),
      thisMonthIncome: (json['thisMonthIncome'] as num).toDouble(),
      completedShifts: json['completedShifts'] as int,
      averageIncomePerShift: (json['averageIncomePerShift'] as num).toDouble(),
    );
  }
}
