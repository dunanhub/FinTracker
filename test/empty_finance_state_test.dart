import 'package:fin_tracker/core/theme/app_theme.dart';
import 'package:fin_tracker/core/theme/theme_preset.dart';
import 'package:fin_tracker/domain/entities/account.dart';
import 'package:fin_tracker/presentation/controllers/budget_controller.dart';
import 'package:fin_tracker/presentation/controllers/debt_controller.dart';
import 'package:fin_tracker/presentation/controllers/finance_controller.dart';
import 'package:fin_tracker/presentation/controllers/goal_controller.dart';
import 'package:fin_tracker/presentation/screens/accounts_screen.dart';
import 'package:fin_tracker/presentation/screens/add_transaction_screen.dart';
import 'package:fin_tracker/presentation/screens/analytics_screen.dart';
import 'package:fin_tracker/presentation/screens/budgets_screen.dart';
import 'package:fin_tracker/presentation/screens/debts_screen.dart';
import 'package:fin_tracker/presentation/screens/goals_screen.dart';
import 'package:fin_tracker/presentation/screens/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

Widget _app(Widget screen, FinanceController finance) => MultiProvider(
  providers: [
    ChangeNotifierProvider<FinanceController>.value(value: finance),
    ChangeNotifierProvider<BudgetController>(create: (_) => BudgetController()),
    ChangeNotifierProvider<GoalController>(create: (_) => GoalController()),
    ChangeNotifierProvider<DebtController>(create: (_) => DebtController()),
  ],
  child: MaterialApp(
    theme: AppTheme.light(AppThemePreset.navy),
    home: screen is AnalyticsScreen ? Scaffold(body: screen) : screen,
  ),
);

void main() {
  testWidgets('empty accounts screen shows add account action', (tester) async {
    final finance = FinanceController();
    await tester.pumpWidget(_app(const AccountsScreen(), finance));
    await tester.pumpAndSettle();

    expect(find.text('У вас пока нет счетов'), findsOneWidget);
    expect(find.text('0 ₸'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Добавить счёт'));
    await tester.pumpAndSettle();
    expect(find.text('Новый счёт'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add transaction with no account leads to account creation', (
    tester,
  ) async {
    final finance = FinanceController();
    await tester.pumpWidget(_app(const AddTransactionScreen(), finance));
    await tester.pumpAndSettle();

    expect(find.text('Сначала нужен счёт'), findsOneWidget);
    expect(find.text('Сохранить операцию'), findsNothing);
    await tester.tap(find.text('Добавить счёт'));
    await tester.pumpAndSettle();
    expect(find.text('Новый счёт'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Мой счёт');
    await tester.tap(find.text('Добавить счёт'));
    await tester.pumpAndSettle();

    expect(finance.accounts, hasLength(1));
    expect(find.text('Сначала нужен счёт'), findsNothing);
    expect(find.text('Сохранить операцию'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transfer with only one account explains the requirement', (
    tester,
  ) async {
    final finance = FinanceController();
    await finance.addAccount(
      name: 'Мой счёт',
      type: AccountType.cash,
      balance: 0,
    );
    await tester.pumpWidget(_app(const AddTransactionScreen(), finance));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Перевод'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить операцию'));
    await tester.pump();
    expect(find.text('Для перевода нужно минимум два счёта'), findsOneWidget);
    expect(finance.transactions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('budget, goal, debt, analytics and report screens stay empty', (
    tester,
  ) async {
    final finance = FinanceController();
    final cases = <(Widget, String)>[
      (const BudgetsScreen(), 'Бюджетов пока нет'),
      (const GoalsScreen(), 'Целей пока нет'),
      (const DebtsScreen(), 'Долгов пока нет'),
      (const AnalyticsScreen(), 'Нет расходов за этот период'),
      (const ReportsScreen(), 'Операций нет'),
    ];
    for (final (screen, expected) in cases) {
      await tester.pumpWidget(_app(screen, finance));
      await tester.pumpAndSettle();
      if (screen is ReportsScreen) {
        await tester.scrollUntilVisible(
          find.text(expected),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
      }
      expect(find.text(expected), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
