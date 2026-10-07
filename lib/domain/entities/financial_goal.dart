class FinancialGoal {
  final String id;
  final String name;

  final double targetAmount;
  final double currentAmount;

  final DateTime? targetDate;

  const FinancialGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
  });

  double get progress {
    if (targetAmount <= 0) {
      return 0;
    }

    return (currentAmount / targetAmount).clamp(0, 1);
  }

  double get remainingAmount {
    final remaining = targetAmount - currentAmount;

    if (remaining < 0) {
      return 0;
    }

    return remaining;
  }
}
