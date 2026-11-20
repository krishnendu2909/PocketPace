class BudgetProfile {
  final int monthlyIncomeMinor;
  final int fixedExpensesMinor;
  final int savingsTargetMinor;
  final int bufferMinor;
  final String currency;

  const BudgetProfile({
    required this.monthlyIncomeMinor,
    required this.fixedExpensesMinor,
    required this.savingsTargetMinor,
    required this.bufferMinor,
    required this.currency,
  });
}