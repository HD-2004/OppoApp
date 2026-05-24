class RevenueStatistics {
  const RevenueStatistics({
    required this.thisWeekIncome,
    required this.thisMonthIncome,
    required this.completedShifts,
    required this.averageIncomePerShift,
  });

  final double thisWeekIncome;
  final double thisMonthIncome;
  final int completedShifts;
  final double averageIncomePerShift;
}
