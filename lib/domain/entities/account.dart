enum AccountType { card, cash, deposit, savings, other }

class Account {
  final String id;
  final String name;
  final AccountType type;
  final double balance;
  final String currency;
  final String? bankName;
  final bool includeInTotal;

  const Account({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.currency = 'KZT',
    this.bankName,
    this.includeInTotal = true,
  });

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    double? balance,
    String? currency,
    String? bankName,
    bool? includeInTotal,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      currency: currency ?? this.currency,
      bankName: bankName ?? this.bankName,
      includeInTotal: includeInTotal ?? this.includeInTotal,
    );
  }
}
