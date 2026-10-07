class SavingsGoal {
  final String id;
  final String name;

  final double targetAmount;
  final double currentAmount;

  final DateTime deadline;
  final DateTime createdAt;

  final String? linkedAccountId;

  const SavingsGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    required this.deadline,
    required this.createdAt,
    this.linkedAccountId,
  });

  SavingsGoal copyWith({
    String? id,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    DateTime? createdAt,
    String? linkedAccountId,
    bool clearLinkedAccount = false,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      linkedAccountId:
          clearLinkedAccount ? null : linkedAccountId ?? this.linkedAccountId,
    );
  }
}
