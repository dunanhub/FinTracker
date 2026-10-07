enum DebtType { iOwe, owedToMe }

class DebtPayment {
  final String id;
  final double amount;
  final DateTime date;

  final String? accountId;
  final String? transactionId;

  const DebtPayment({
    required this.id,
    required this.amount,
    required this.date,
    this.accountId,
    this.transactionId,
  });
}

class Debt {
  final String id;
  final DebtType type;

  final String person;

  final double originalAmount;
  final double remainingAmount;

  final DateTime? deadline;
  final String? note;

  final DateTime createdAt;

  final List<DebtPayment> payments;

  const Debt({
    required this.id,
    required this.type,
    required this.person,
    required this.originalAmount,
    required this.remainingAmount,
    required this.createdAt,
    this.deadline,
    this.note,
    this.payments = const [],
  });

  bool get isPaid => remainingAmount <= 0;

  double get paidAmount => originalAmount - remainingAmount;

  double get progress {
    if (originalAmount <= 0) {
      return 0;
    }

    return (paidAmount / originalAmount).clamp(0.0, 1.0).toDouble();
  }

  Debt copyWith({
    String? id,
    DebtType? type,
    String? person,
    double? originalAmount,
    double? remainingAmount,
    DateTime? deadline,
    bool clearDeadline = false,
    String? note,
    bool clearNote = false,
    DateTime? createdAt,
    List<DebtPayment>? payments,
  }) {
    return Debt(
      id: id ?? this.id,
      type: type ?? this.type,
      person: person ?? this.person,
      originalAmount: originalAmount ?? this.originalAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      deadline: clearDeadline ? null : deadline ?? this.deadline,
      note: clearNote ? null : note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      payments: payments ?? this.payments,
    );
  }
}
