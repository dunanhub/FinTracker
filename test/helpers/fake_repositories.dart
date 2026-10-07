import 'package:fin_tracker/domain/entities/account.dart';
import 'package:fin_tracker/domain/entities/budget.dart';
import 'package:fin_tracker/domain/entities/debt.dart';
import 'package:fin_tracker/domain/entities/finance_transaction.dart';
import 'package:fin_tracker/domain/entities/savings_goal.dart';
import 'package:fin_tracker/domain/repositories/budget_repository.dart';
import 'package:fin_tracker/domain/repositories/debt_repository.dart';
import 'package:fin_tracker/domain/repositories/finance_repository.dart';
import 'package:fin_tracker/domain/repositories/goal_repository.dart';

class FakeFinanceRepository implements FinanceRepository {
  List<Account> accounts;
  List<FinanceTransaction> transactions;
  int saveCount = 0;

  FakeFinanceRepository({
    this.accounts = const [],
    this.transactions = const [],
  });

  @override
  Future<FinanceStorageData> load() async => FinanceStorageData(
    accounts: List.of(accounts),
    transactions: List.of(transactions),
  );

  @override
  Future<void> save({
    required List<FinanceTransaction> transactions,
    required List<Account> accounts,
  }) async {
    this.accounts = List.of(accounts);
    this.transactions = List.of(transactions);
    saveCount++;
  }
}

class FakeBudgetRepository implements BudgetRepository {
  List<Budget> values;
  FakeBudgetRepository([this.values = const []]);

  @override
  Future<List<Budget>> load() async => List.of(values);

  @override
  Future<void> save(List<Budget> budgets) async => values = List.of(budgets);
}

class FakeGoalRepository implements GoalRepository {
  List<SavingsGoal> values;
  FakeGoalRepository([this.values = const []]);

  @override
  Future<List<SavingsGoal>> load() async => List.of(values);

  @override
  Future<void> save(List<SavingsGoal> goals) async => values = List.of(goals);
}

class FakeDebtRepository implements DebtRepository {
  List<Debt> values;
  FakeDebtRepository([this.values = const []]);

  @override
  Future<List<Debt>> load() async => List.of(values);

  @override
  Future<void> save(List<Debt> debts) async => values = List.of(debts);
}
