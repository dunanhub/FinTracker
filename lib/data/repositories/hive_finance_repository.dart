import 'package:hive/hive.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/finance_transaction.dart';
import '../../domain/repositories/finance_repository.dart';

class HiveFinanceRepository implements FinanceRepository {
  static const String _legacyBoxName = 'fintracker_finance';

  static const String _transactionsKey = 'transactions';
  static const String _accountsKey = 'accounts_v2';
  static const String _legacyBalancesKey = 'account_balances';

  Box<dynamic>? _box;

  String _scope = 'legacy';

  String get currentScope => _scope;

  bool get isLegacyScope => _scope == 'legacy';

  bool get hasStoredData {
    final box = _box;

    if (box == null) {
      return false;
    }

    return box.containsKey(_transactionsKey) ||
        box.containsKey(_accountsKey) ||
        box.containsKey(_legacyBalancesKey);
  }

  Future<void> init({String scope = 'legacy'}) async {
    _scope = scope;

    _box = await Hive.openBox<dynamic>(_boxName(scope));
  }

  Future<void> switchScope(String scope) async {
    if (_scope == scope && _box != null) {
      return;
    }

    _scope = scope;

    _box = await Hive.openBox<dynamic>(_boxName(scope));
  }

  String _boxName(String scope) {
    if (scope == 'legacy') {
      return _legacyBoxName;
    }

    return '${_legacyBoxName}_${_safeScope(scope)}';
  }

  String _safeScope(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  Box<dynamic> get _storage {
    final box = _box;

    if (box == null) {
      throw StateError('HiveFinanceRepository.init() must be called first.');
    }

    return box;
  }

  @override
  Future<FinanceStorageData?> load() async {
    final rawTransactions = _storage.get(_transactionsKey);

    final rawAccounts = _storage.get(_accountsKey);

    final rawLegacyBalances = _storage.get(_legacyBalancesKey);

    if (rawTransactions == null &&
        rawAccounts == null &&
        rawLegacyBalances == null) {
      return null;
    }

    final transactions = <FinanceTransaction>[];

    if (rawTransactions is List) {
      for (final rawItem in rawTransactions) {
        if (rawItem is! Map) {
          continue;
        }

        try {
          transactions.add(_transactionFromMap(rawItem));
        } catch (_) {
          // Повреждённую запись пропускаем.
        }
      }
    }

    final accounts = <Account>[];

    if (rawAccounts is List) {
      for (final rawItem in rawAccounts) {
        if (rawItem is! Map) {
          continue;
        }

        try {
          accounts.add(_accountFromMap(rawItem));
        } catch (_) {
          // Повреждённую запись пропускаем.
        }
      }
    }

    if (rawAccounts == null && rawLegacyBalances is Map) {
      accounts.addAll(_legacyAccountsFromBalances(rawLegacyBalances));

      await save(transactions: transactions, accounts: accounts);
    }

    return FinanceStorageData(transactions: transactions, accounts: accounts);
  }

  @override
  Future<void> save({
    required List<FinanceTransaction> transactions,
    required List<Account> accounts,
  }) async {
    await _storage.put(
      _transactionsKey,
      transactions.map(_transactionToMap).toList(),
    );

    await _storage.put(_accountsKey, accounts.map(_accountToMap).toList());

    if (_storage.containsKey(_legacyBalancesKey)) {
      await _storage.delete(_legacyBalancesKey);
    }
  }

  Map<String, dynamic> _accountToMap(Account account) {
    return {
      'id': account.id,
      'name': account.name,
      'type': account.type.name,
      'balance': account.balance,
      'currency': account.currency,
      'bankName': account.bankName,
      'includeInTotal': account.includeInTotal,
    };
  }

  Account _accountFromMap(Map<dynamic, dynamic> map) {
    return Account(
      id: map['id'] as String,
      name: map['name'] as String,
      type: AccountType.values.byName(map['type'] as String),
      balance: (map['balance'] as num).toDouble(),
      currency: map['currency'] as String? ?? 'KZT',
      bankName: map['bankName'] as String?,
      includeInTotal: map['includeInTotal'] as bool? ?? true,
    );
  }

  List<Account> _legacyAccountsFromBalances(Map<dynamic, dynamic> balances) {
    const knownAccounts = <String, (String, AccountType, String?)>{
      'kaspi': ('Kaspi Gold', AccountType.card, 'Kaspi'),
      'halyk': ('Halyk', AccountType.card, 'Halyk Bank'),
      'deposit': ('Депозит', AccountType.deposit, 'Отбасы банк'),
      'cash': ('Наличные', AccountType.cash, null),
    };
    return [
      for (final entry in balances.entries)
        if (entry.key is String && entry.value is num)
          Account(
            id: entry.key as String,
            name: knownAccounts[entry.key]?.$1 ?? entry.key as String,
            type: knownAccounts[entry.key]?.$2 ?? AccountType.other,
            bankName: knownAccounts[entry.key]?.$3,
            balance: (entry.value as num).toDouble(),
          ),
    ];
  }

  Map<String, dynamic> _transactionToMap(FinanceTransaction transaction) {
    return {
      'id': transaction.id,
      'type': transaction.type.name,
      'amount': transaction.amount,
      'accountId': transaction.accountId,
      'destinationAccountId': transaction.destinationAccountId,
      'categoryId': transaction.categoryId,
      'title': transaction.title,
      'person': transaction.person,
      'description': transaction.description,
      'date': transaction.date.toIso8601String(),
      'receiptPath': transaction.receiptPath,
      'receiptStoragePath': transaction.receiptStoragePath,
      'latitude': transaction.latitude,
      'longitude': transaction.longitude,
    };
  }

  FinanceTransaction _transactionFromMap(Map<dynamic, dynamic> map) {
    return FinanceTransaction(
      id: map['id'] as String,
      type: FinanceTransactionType.values.byName(map['type'] as String),
      amount: (map['amount'] as num).toDouble(),
      accountId: map['accountId'] as String,
      destinationAccountId: map['destinationAccountId'] as String?,
      categoryId: map['categoryId'] as String?,
      title: map['title'] as String,
      person: map['person'] as String?,
      description: map['description'] as String?,
      date: DateTime.parse(map['date'] as String),
      receiptPath: map['receiptPath'] as String?,
      receiptStoragePath: map['receiptStoragePath'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}
