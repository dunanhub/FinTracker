import 'package:flutter/foundation.dart';

import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';

class BudgetController extends ChangeNotifier {
  final BudgetRepository? repository;

  BudgetController({this.repository});

  final List<Budget> _budgets = [];

  List<Budget> get budgets {
    final result = [..._budgets];

    result.sort((a, b) => a.categoryId.compareTo(b.categoryId));

    return List.unmodifiable(result);
  }

  Future<void> load() async {
    final storage = repository;

    if (storage == null) {
      return;
    }

    final saved = await storage.load();

    _budgets
      ..clear()
      ..addAll(saved);

    notifyListeners();
  }

  Budget? budgetById(String id) {
    for (final budget in _budgets) {
      if (budget.id == id) {
        return budget;
      }
    }

    return null;
  }

  Budget? budgetForCategory(String categoryId) {
    for (final budget in _budgets) {
      if (budget.categoryId == categoryId) {
        return budget;
      }
    }

    return null;
  }

  bool hasBudgetForCategory(String categoryId, {String? exceptBudgetId}) {
    return _budgets.any(
      (budget) =>
          budget.categoryId == categoryId && budget.id != exceptBudgetId,
    );
  }

  Future<bool> addBudget({
    required String categoryId,
    required double monthlyLimit,
  }) async {
    if (monthlyLimit <= 0) {
      return false;
    }

    if (hasBudgetForCategory(categoryId)) {
      return false;
    }

    _budgets.add(
      Budget(
        id: 'budget-${DateTime.now().microsecondsSinceEpoch}',
        categoryId: categoryId,
        monthlyLimit: monthlyLimit,
        createdAt: DateTime.now(),
      ),
    );

    notifyListeners();

    await _save();

    return true;
  }

  Future<bool> updateBudget({
    required String id,
    required String categoryId,
    required double monthlyLimit,
    required bool enabled,
  }) async {
    final index = _budgets.indexWhere((budget) => budget.id == id);

    if (index == -1 || monthlyLimit <= 0) {
      return false;
    }

    if (hasBudgetForCategory(categoryId, exceptBudgetId: id)) {
      return false;
    }

    final current = _budgets[index];

    _budgets[index] = current.copyWith(
      categoryId: categoryId,
      monthlyLimit: monthlyLimit,
      enabled: enabled,
    );

    notifyListeners();

    await _save();

    return true;
  }

  Future<bool> deleteBudget(String id) async {
    final index = _budgets.indexWhere((budget) => budget.id == id);

    if (index == -1) {
      return false;
    }

    _budgets.removeAt(index);

    notifyListeners();

    await _save();

    return true;
  }

  Future<void> _save() async {
    final storage = repository;

    if (storage == null) {
      return;
    }

    await storage.save(_budgets);
  }
}
