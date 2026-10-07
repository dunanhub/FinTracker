import 'package:fin_tracker/core/theme/app_theme.dart';
import 'package:fin_tracker/core/theme/theme_preset.dart';
import 'package:fin_tracker/domain/entities/account.dart';
import 'package:fin_tracker/domain/entities/budget.dart';
import 'package:fin_tracker/domain/entities/debt.dart';
import 'package:fin_tracker/domain/entities/finance_transaction.dart';
import 'package:fin_tracker/domain/entities/savings_goal.dart';
import 'package:fin_tracker/presentation/controllers/budget_controller.dart';
import 'package:fin_tracker/presentation/controllers/debt_controller.dart';
import 'package:fin_tracker/presentation/controllers/finance_controller.dart';
import 'package:fin_tracker/presentation/controllers/goal_controller.dart';
import 'package:fin_tracker/presentation/screens/budgets_screen.dart';
import 'package:fin_tracker/presentation/screens/debts_screen.dart';
import 'package:fin_tracker/presentation/screens/goals_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'helpers/fake_repositories.dart';

Future<void> showFeature(
  WidgetTester tester,
  Widget screen, {
  required FinanceController finance,
  BudgetController? budgets,
  GoalController? goals,
  DebtController? debts,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FinanceController>.value(value: finance),
        if (budgets != null)
          ChangeNotifierProvider<BudgetController>.value(value: budgets),
        if (goals != null)
          ChangeNotifierProvider<GoalController>.value(value: goals),
        if (debts != null)
          ChangeNotifierProvider<DebtController>.value(value: debts),
      ],
      child: MaterialApp(
        theme: AppTheme.light(AppThemePreset.navy),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('budget screen sums current-month spending and opens editing', (
    tester,
  ) async {
    final now = DateTime.now();
    final finance = FinanceController(
      repository: FakeFinanceRepository(
        accounts: const [
          Account(
            id: 'cash',
            name: 'Cash',
            type: AccountType.cash,
            balance: 1000,
          ),
        ],
        transactions: [
          FinanceTransaction(
            id: 'food-this-month',
            type: FinanceTransactionType.expense,
            amount: 120,
            accountId: 'cash',
            categoryId: 'food',
            title: 'Lunch',
            date: DateTime(now.year, now.month, 1),
          ),
          FinanceTransaction(
            id: 'food-last-month',
            type: FinanceTransactionType.expense,
            amount: 900,
            accountId: 'cash',
            categoryId: 'food',
            title: 'Old lunch',
            date: DateTime(now.year, now.month - 1, 1),
          ),
        ],
      ),
    );
    await finance.load();
    final budgets = BudgetController(
      repository: FakeBudgetRepository([
        Budget(
          id: 'food-budget',
          categoryId: 'food',
          monthlyLimit: 100,
          createdAt: now,
        ),
      ]),
    );
    await budgets.load();
    await showFeature(
      tester,
      const BudgetsScreen(),
      finance: finance,
      budgets: budgets,
    );

    expect(find.text('120 / 100 ₸'), findsOneWidget);
    expect(find.text('Лимит превышен на 20 ₸'), findsOneWidget);
    expect(find.text('120 из 100 ₸'), findsOneWidget);
    await tester.tap(find.text('Еда'));
    await tester.pumpAndSettle();
    expect(find.text('Редактировать бюджет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('linked goal top-up creates transfer and updates progress', (
    tester,
  ) async {
    final finance = FinanceController(
      repository: FakeFinanceRepository(
        accounts: const [
          Account(
            id: 'cash',
            name: 'Cash',
            type: AccountType.cash,
            balance: 500,
          ),
          Account(
            id: 'savings',
            name: 'Savings',
            type: AccountType.savings,
            balance: 100,
          ),
        ],
      ),
    );
    await finance.load();
    final goals = GoalController(
      repository: FakeGoalRepository([
        SavingsGoal(
          id: 'goal',
          name: 'Trip',
          targetAmount: 500,
          currentAmount: 100,
          deadline: DateTime.now().add(const Duration(days: 60)),
          createdAt: DateTime.now(),
          linkedAccountId: 'savings',
        ),
      ]),
    );
    await goals.load();
    await showFeature(
      tester,
      const GoalsScreen(),
      finance: finance,
      goals: goals,
    );
    expect(find.text('Trip'), findsOneWidget);
    await tester.tap(find.text('Пополнить цель'));
    await tester.pumpAndSettle();
    expect(find.text('Перевод на Savings'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '150');
    await tester.tap(find.text('Пополнить').last);
    await tester.pumpAndSettle();

    expect(goals.goalById('goal')!.currentAmount, 250);
    expect(finance.accountBalance('cash'), 350);
    expect(finance.accountBalance('savings'), 250);
    expect(finance.transactions.single.type, FinanceTransactionType.transfer);
    expect(finance.transactions.single.destinationAccountId, 'savings');
    expect(tester.takeException(), isNull);
  });

  testWidgets('debt repayment creates excluded finance expense', (
    tester,
  ) async {
    final finance = FinanceController(
      repository: FakeFinanceRepository(
        accounts: const [
          Account(
            id: 'cash',
            name: 'Cash',
            type: AccountType.cash,
            balance: 500,
          ),
        ],
      ),
    );
    await finance.load();
    final debts = DebtController(
      repository: FakeDebtRepository([
        Debt(
          id: 'debt',
          type: DebtType.iOwe,
          person: 'Alex',
          originalAmount: 300,
          remainingAmount: 300,
          createdAt: DateTime.now(),
        ),
      ]),
    );
    await debts.load();
    await showFeature(
      tester,
      const DebtsScreen(),
      finance: finance,
      debts: debts,
    );
    expect(find.text('Alex'), findsOneWidget);
    await tester.tap(find.text('Alex'));
    await tester.pumpAndSettle();
    expect(find.text('Пока выплат нет'), findsOneWidget);
    await tester.tap(find.text('Я выплатил'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '120');
    await tester.tap(find.text('Выплатить'));
    await tester.pumpAndSettle();

    expect(debts.debtById('debt')!.remainingAmount, 180);
    expect(debts.debtById('debt')!.payments, hasLength(1));
    expect(finance.accountBalance('cash'), 380);
    expect(
      finance.transactions.single.categoryId,
      FinanceController.debtPaymentCategoryId,
    );
    expect(finance.monthlyExpense, 0);
    expect(tester.takeException(), isNull);
  });
}
