import 'package:hive/hive.dart';

import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';

class HiveDebtRepository implements DebtRepository {
  static const String _legacyBoxName = 'fintracker_debts';

  static const String _debtsKey = 'debts';

  Box<dynamic>? _box;

  String _scope = 'legacy';

  bool get isLegacyScope => _scope == 'legacy';

  bool get hasStoredData {
    return _box?.containsKey(_debtsKey) ?? false;
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
      throw StateError('HiveDebtRepository.init() must be called first.');
    }

    return box;
  }

  @override
  Future<List<Debt>> load() async {
    final raw = _storage.get(_debtsKey);

    if (raw is! List) {
      return [];
    }

    final result = <Debt>[];

    for (final item in raw) {
      if (item is! Map) {
        continue;
      }

      try {
        result.add(_fromMap(item));
      } catch (_) {
        // Повреждённую запись пропускаем.
      }
    }

    return result;
  }

  @override
  Future<void> save(List<Debt> debts) async {
    await _storage.put(_debtsKey, debts.map(_toMap).toList());
  }

  Map<String, dynamic> _toMap(Debt debt) {
    return {
      'id': debt.id,
      'type': debt.type.name,
      'person': debt.person,
      'originalAmount': debt.originalAmount,
      'remainingAmount': debt.remainingAmount,
      'deadline': debt.deadline?.toIso8601String(),
      'note': debt.note,
      'createdAt': debt.createdAt.toIso8601String(),
      'payments':
          debt.payments
              .map(
                (payment) => {
                  'id': payment.id,
                  'amount': payment.amount,
                  'date': payment.date.toIso8601String(),
                  'accountId': payment.accountId,
                  'transactionId': payment.transactionId,
                },
              )
              .toList(),
    };
  }

  Debt _fromMap(Map<dynamic, dynamic> map) {
    final payments = <DebtPayment>[];

    final rawPayments = map['payments'];

    if (rawPayments is List) {
      for (final item in rawPayments) {
        if (item is! Map) {
          continue;
        }

        payments.add(
          DebtPayment(
            id: item['id'] as String,
            amount: (item['amount'] as num).toDouble(),
            date: DateTime.parse(item['date'] as String),
            accountId: item['accountId'] as String?,
            transactionId: item['transactionId'] as String?,
          ),
        );
      }
    }

    return Debt(
      id: map['id'] as String,
      type: DebtType.values.byName(map['type'] as String),
      person: map['person'] as String,
      originalAmount: (map['originalAmount'] as num).toDouble(),
      remainingAmount: (map['remainingAmount'] as num).toDouble(),
      deadline:
          map['deadline'] == null
              ? null
              : DateTime.parse(map['deadline'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      payments: payments,
    );
  }
}
