import '../entities/budget.dart';

abstract class BudgetRepository {
  Future<List<Budget>> load();

  Future<void> save(List<Budget> budgets);
}
