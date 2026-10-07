import 'package:flutter/foundation.dart';

import '../../domain/entities/savings_goal.dart';
import '../../domain/repositories/goal_repository.dart';

class GoalController extends ChangeNotifier {
  final GoalRepository? repository;

  GoalController({this.repository});

  final List<SavingsGoal> _goals = [];

  List<SavingsGoal> get goals {
    final result = [..._goals];

    result.sort((a, b) {
      final aCompleted = a.currentAmount >= a.targetAmount;

      final bCompleted = b.currentAmount >= b.targetAmount;

      if (aCompleted != bCompleted) {
        return aCompleted ? 1 : -1;
      }

      return a.deadline.compareTo(b.deadline);
    });

    return List.unmodifiable(result);
  }

  Future<void> load() async {
    final storage = repository;

    if (storage == null) {
      return;
    }

    final saved = await storage.load();

    _goals
      ..clear()
      ..addAll(saved);

    notifyListeners();
  }

  SavingsGoal? goalById(String id) {
    for (final goal in _goals) {
      if (goal.id == id) {
        return goal;
      }
    }

    return null;
  }

  Future<bool> addGoal({
    required String name,
    required double targetAmount,
    required double currentAmount,
    required DateTime deadline,
    String? linkedAccountId,
  }) async {
    final cleanName = name.trim();

    if (cleanName.isEmpty ||
        targetAmount <= 0 ||
        currentAmount < 0 ||
        currentAmount > targetAmount) {
      return false;
    }

    _goals.add(
      SavingsGoal(
        id: 'goal-${DateTime.now().microsecondsSinceEpoch}',
        name: cleanName,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        deadline: deadline,
        createdAt: DateTime.now(),
        linkedAccountId: linkedAccountId,
      ),
    );

    notifyListeners();

    await _save();

    return true;
  }

  Future<bool> updateGoal({
    required String id,
    required String name,
    required double targetAmount,
    required double currentAmount,
    required DateTime deadline,
    String? linkedAccountId,
  }) async {
    final index = _goals.indexWhere((goal) => goal.id == id);

    if (index == -1 ||
        name.trim().isEmpty ||
        targetAmount <= 0 ||
        currentAmount < 0 ||
        currentAmount > targetAmount) {
      return false;
    }

    final current = _goals[index];

    _goals[index] = current.copyWith(
      name: name.trim(),
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      deadline: deadline,
      linkedAccountId: linkedAccountId,
      clearLinkedAccount: linkedAccountId == null,
    );

    notifyListeners();

    await _save();

    return true;
  }

  Future<bool> deleteGoal(String id) async {
    final index = _goals.indexWhere((goal) => goal.id == id);

    if (index == -1) {
      return false;
    }

    _goals.removeAt(index);

    notifyListeners();

    await _save();

    return true;
  }

  Future<bool> addMoney({required String id, required double amount}) async {
    if (amount <= 0) {
      return false;
    }

    final index = _goals.indexWhere((goal) => goal.id == id);

    if (index == -1) {
      return false;
    }

    final goal = _goals[index];

    final left = remaining(goal);

    if (left <= 0 || amount > left) {
      return false;
    }

    _goals[index] = goal.copyWith(currentAmount: goal.currentAmount + amount);

    notifyListeners();

    await _save();

    return true;
  }

  double progress(SavingsGoal goal) {
    if (goal.targetAmount <= 0) {
      return 0;
    }

    return (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0).toDouble();
  }

  double remaining(SavingsGoal goal) {
    final result = goal.targetAmount - goal.currentAmount;

    return result < 0 ? 0 : result;
  }

  int monthsRemaining(SavingsGoal goal) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final deadline = DateTime(
      goal.deadline.year,
      goal.deadline.month,
      goal.deadline.day,
    );

    if (!deadline.isAfter(today)) {
      return 1;
    }

    var months = (deadline.year - now.year) * 12 + deadline.month - now.month;

    if (goal.deadline.day > now.day) {
      months++;
    }

    if (months < 1) {
      return 1;
    }

    return months;
  }

  double monthlyRequired(SavingsGoal goal) {
    final left = remaining(goal);

    if (left <= 0) {
      return 0;
    }

    return left / monthsRemaining(goal);
  }

  Future<void> _save() async {
    final storage = repository;

    if (storage == null) {
      return;
    }

    await storage.save(_goals);
  }
}
