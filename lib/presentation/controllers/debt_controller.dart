import 'package:flutter/foundation.dart';

import '../../domain/entities/debt.dart';
import '../../domain/repositories/debt_repository.dart';

class DebtController extends ChangeNotifier {
  final DebtRepository? repository;

  DebtController({this.repository});

  final List<Debt> _debts = [];

  List<Debt> get debts {
    final result = [..._debts];

    result.sort((a, b) {
      if (a.isPaid != b.isPaid) {
        return a.isPaid ? 1 : -1;
      }

      if (a.deadline == null && b.deadline == null) {
        return b.createdAt.compareTo(a.createdAt);
      }

      if (a.deadline == null) {
        return 1;
      }

      if (b.deadline == null) {
        return -1;
      }

      return a.deadline!.compareTo(b.deadline!);
    });

    return List.unmodifiable(result);
  }

  Debt? debtById(String id) {
    for (final debt in _debts) {
      if (debt.id == id) {
        return debt;
      }
    }

    return null;
  }

  double get totalIOwe {
    return _debts
        .where((debt) => debt.type == DebtType.iOwe && !debt.isPaid)
        .fold<double>(0, (sum, debt) => sum + debt.remainingAmount);
  }

  double get totalOwedToMe {
    return _debts
        .where((debt) => debt.type == DebtType.owedToMe && !debt.isPaid)
        .fold<double>(0, (sum, debt) => sum + debt.remainingAmount);
  }

  Future<void> load() async {
    final storage = repository;

    if (storage == null) {
      return;
    }

    final saved = await storage.load();

    _debts
      ..clear()
      ..addAll(saved);

    notifyListeners();
  }

  Future<bool> addDebt({
    required DebtType type,
    required String person,
    required double amount,
    DateTime? deadline,
    String? note,
  }) async {
    final cleanPerson = person.trim();

    if (cleanPerson.isEmpty || amount <= 0) {
      return false;
    }

    _debts.add(
      Debt(
        id: 'debt-${DateTime.now().microsecondsSinceEpoch}',
        type: type,
        person: cleanPerson,
        originalAmount: amount,
        remainingAmount: amount,
        deadline: deadline,
        note: note?.trim().isEmpty == true ? null : note?.trim(),
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();

    await _save();

    return true;
  }

  Future<bool> updateDebt({
    required String id,
    required DebtType type,
    required String person,
    required double amount,
    DateTime? deadline,
    String? note,
  }) async {
    final index = _debts.indexWhere((debt) => debt.id == id);

    if (index == -1 || person.trim().isEmpty || amount <= 0) {
      return false;
    }

    final current = _debts[index];

    final alreadyPaid = current.originalAmount - current.remainingAmount;

    final newRemaining = (amount - alreadyPaid).clamp(0.0, amount).toDouble();

    _debts[index] = current.copyWith(
      type: type,
      person: person.trim(),
      originalAmount: amount,
      remainingAmount: newRemaining,
      deadline: deadline,
      clearDeadline: deadline == null,
      note: note?.trim(),
      clearNote: note == null || note.trim().isEmpty,
    );

    notifyListeners();

    await _save();

    return true;
  }

  Future<bool> addPayment({
    required String debtId,
    required double amount,
    String? accountId,
    String? transactionId,
  }) async {
    final index = _debts.indexWhere((debt) => debt.id == debtId);

    if (index == -1 || amount <= 0) {
      return false;
    }

    final debt = _debts[index];

    if (debt.isPaid || amount > debt.remainingAmount) {
      return false;
    }

    final payment = DebtPayment(
      id: 'payment-${DateTime.now().microsecondsSinceEpoch}',
      amount: amount,
      date: DateTime.now(),
      accountId: accountId,
      transactionId: transactionId,
    );

    _debts[index] = debt.copyWith(
      remainingAmount: debt.remainingAmount - amount,
      payments: [...debt.payments, payment],
    );

    notifyListeners();

    await _save();

    return true;
  }

  Future<bool> deleteDebt(String id) async {
    final index = _debts.indexWhere((debt) => debt.id == id);

    if (index == -1) {
      return false;
    }

    _debts.removeAt(index);

    notifyListeners();

    await _save();

    return true;
  }

  Future<void> _save() async {
    final storage = repository;

    if (storage == null) {
      return;
    }

    await storage.save(_debts);
  }
}
