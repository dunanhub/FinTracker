enum FinanceTransactionType { expense, income, transfer }

class FinanceTransaction {
  final String id;
  final FinanceTransactionType type;
  final double amount;

  final String accountId;
  final String? destinationAccountId;

  final String? categoryId;

  final String title;
  final String? person;
  final String? description;

  final DateTime date;

  final String? receiptPath;
  final String? receiptStoragePath;

  final double? latitude;
  final double? longitude;

  const FinanceTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.accountId,
    this.destinationAccountId,
    this.categoryId,
    required this.title,
    this.person,
    this.description,
    required this.date,
    this.receiptPath,
    this.receiptStoragePath,
    this.latitude,
    this.longitude,
  });

  FinanceTransaction copyWith({
    String? id,
    FinanceTransactionType? type,
    double? amount,
    String? accountId,
    String? destinationAccountId,
    String? categoryId,
    String? title,
    String? person,
    String? description,
    DateTime? date,
    String? receiptPath,
    bool clearReceiptPath = false,
    String? receiptStoragePath,
    bool clearReceiptStoragePath = false,
    double? latitude,
    double? longitude,
  }) {
    return FinanceTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      accountId: accountId ?? this.accountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      person: person ?? this.person,
      description: description ?? this.description,
      date: date ?? this.date,
      receiptPath: clearReceiptPath ? null : receiptPath ?? this.receiptPath,
      receiptStoragePath:
          clearReceiptStoragePath
              ? null
              : receiptStoragePath ?? this.receiptStoragePath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
