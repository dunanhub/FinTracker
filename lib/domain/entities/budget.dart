class Budget {
  final String id;
  final String categoryId;
  final double monthlyLimit;
  final bool enabled;
  final DateTime createdAt;

  const Budget({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
    required this.createdAt,
    this.enabled = true,
  });

  Budget copyWith({
    String? id,
    String? categoryId,
    double? monthlyLimit,
    bool? enabled,
    DateTime? createdAt,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      enabled: enabled ?? this.enabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
