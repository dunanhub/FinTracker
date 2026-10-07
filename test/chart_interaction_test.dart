import 'package:fin_tracker/domain/entities/finance_transaction.dart';
import 'package:fin_tracker/core/theme/app_theme.dart';
import 'package:fin_tracker/core/theme/theme_preset.dart';
import 'package:fin_tracker/presentation/controllers/finance_controller.dart';
import 'package:fin_tracker/presentation/screens/analytics_screen.dart';
import 'package:fin_tracker/presentation/widgets/smooth_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('dashboard and analytics dates match their expense totals', () async {
    final finance = FinanceController();
    await finance.addTransaction(
      type: FinanceTransactionType.expense,
      amount: 1234,
      accountId: 'cash',
      title: 'Покупка',
      date: DateTime(2030, 1, 1, 10),
    );
    await finance.addTransaction(
      type: FinanceTransactionType.income,
      amount: 500,
      accountId: 'cash',
      title: 'Доход',
      date: DateTime(2030, 1, 1, 11),
    );
    final at = DateTime(2030, 1, 1, 12);
    final dashboard = finance.expenseChartSeries(now: at);
    expect(dashboard.dates.length, 8);
    expect(dashboard.dates.first, DateTime(2029, 12, 25));
    expect(dashboard.dates.last, DateTime(2030, 1, 1));
    expect(dashboard.values.last, 1234);
    expect(dashboard.values.first, 0);
    expect(finance.expenseChartSeries(days: 0, now: at).values, isEmpty);

    final week = finance.analyticsSnapshot(AnalyticsPeriod.week, at: at);
    expect(week.chartDates.length, 7);
    expect(week.chartDates.last, DateTime(2030, 1, 1));
    expect(week.chartValues.last, 1234);

    final month = finance.analyticsSnapshot(AnalyticsPeriod.month, at: at);
    expect(month.chartDates, [DateTime(2030, 1, 1)]);
    expect(month.chartValues, [1234]);

    final year = finance.analyticsSnapshot(AnalyticsPeriod.year, at: at);
    expect(year.chartDates, [DateTime(2030, 1, 1)]);
    expect(year.chartValues, [1234]);

    final empty = finance.analyticsSnapshot(
      AnalyticsPeriod.month,
      at: DateTime(2031, 1, 1),
    );
    expect(empty.chartDates, [DateTime(2031, 1, 1)]);
    expect(empty.chartValues, [0]);
  });

  test('nearest chart index clamps at both edges', () {
    expect(chartIndexForDx(-30, 200, 3), 0);
    expect(chartIndexForDx(100, 200, 3), 1);
    expect(chartIndexForDx(240, 200, 3), 2);
    expect(chartIndexForDx(100, 200, 1), 0);
    expect(chartPointForIndex([1234], 0, const Size(200, 120)).dx, 100);
  });

  test(
    'chart totals combine same-day expenses and omit debt payments',
    () async {
      final finance = FinanceController();
      final date = DateTime(2032, 4, 2);
      for (final amount in [10.0, 20.0]) {
        await finance.addTransaction(
          type: FinanceTransactionType.expense,
          amount: amount,
          accountId: 'cash',
          categoryId: 'food',
          title: 'Expense',
          date: date,
        );
      }
      await finance.addTransaction(
        type: FinanceTransactionType.expense,
        amount: 99,
        accountId: 'cash',
        categoryId: FinanceController.debtPaymentCategoryId,
        title: 'Debt payment',
        date: date,
      );
      final dashboard = finance.expenseChartSeries(now: date);
      expect(dashboard.values.last, 30);
      final month = finance.analyticsSnapshot(AnalyticsPeriod.month, at: date);
      expect(month.chartValues[1], 30);
      final year = finance.analyticsSnapshot(AnalyticsPeriod.year, at: date);
      expect(year.chartValues[3], 30);
    },
  );

  testWidgets('drag shows nearest date and amount, then hides on release', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: SmoothLineChart(
                values: const [10, 0, 3000],
                dates: [
                  DateTime(2030, 1, 1),
                  DateTime(2030, 1, 2),
                  DateTime(2030, 1, 3),
                ],
                lineColor: Colors.blue,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(SmoothLineChart));
    final gesture = await tester.startGesture(
      Offset(rect.left + 2, rect.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.text('01.01.2030'), findsOneWidget);
    expect(find.text('10 ₸'), findsOneWidget);
    final leftTooltip = tester.getRect(
      find.byKey(const ValueKey('chart-tooltip')),
    );
    expect(leftTooltip.left, greaterThanOrEqualTo(rect.left));
    await gesture.moveTo(Offset(rect.right - 2, rect.center.dy));
    await tester.pump();
    expect(find.text('03.01.2030'), findsOneWidget);
    expect(find.text('3 000 ₸'), findsOneWidget);
    final rightTooltip = tester.getRect(
      find.byKey(const ValueKey('chart-tooltip')),
    );
    expect(rightTooltip.right, lessThanOrEqualTo(rect.right));
    await gesture.up();
    await tester.pump();
    expect(find.text('03.01.2030'), findsNothing);
  });

  testWidgets('single monthly point displays its real value', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 170,
              child: SmoothLineChart(
                values: const [1234],
                dates: [DateTime(2030, 1, 1)],
                showMonthOnly: true,
                lineColor: Colors.blue,
                height: 100,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(SmoothLineChart));
    final gesture = await tester.startGesture(rect.center);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Январь 2030'), findsOneWidget);
    expect(find.text('1 234 ₸'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await gesture.up();
    await tester.pump();
    expect(find.text('Январь 2030'), findsNothing);
  });

  testWidgets('vertical drag over chart still scrolls page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              SmoothLineChart(
                values: const [0, 10],
                dates: [DateTime(2030, 1, 1), DateTime(2030, 1, 2)],
                lineColor: Colors.blue,
              ),
              const SizedBox(height: 1500),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = tester.state<ScrollableState>(find.byType(Scrollable));
    await tester.drag(find.byType(SmoothLineChart), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(list.position.pixels, greaterThan(0));
  });

  testWidgets('analytics period changes chart dates and month format', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<FinanceController>.value(
        value: FinanceController(),
        child: MaterialApp(
          theme: AppTheme.light(AppThemePreset.navy),
          home: const Scaffold(body: AnalyticsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SmoothLineChart>(find.byType(SmoothLineChart))
          .showMonthOnly,
      isFalse,
    );
    await tester.tap(find.text('Год'));
    await tester.pumpAndSettle();
    final yearChart = tester.widget<SmoothLineChart>(
      find.byType(SmoothLineChart),
    );
    expect(yearChart.showMonthOnly, isTrue);
    expect(yearChart.dates.length, DateTime.now().month);
    await tester.tap(find.text('Неделя'));
    await tester.pumpAndSettle();
    final weekChart = tester.widget<SmoothLineChart>(
      find.byType(SmoothLineChart),
    );
    expect(weekChart.showMonthOnly, isFalse);
    expect(weekChart.dates.length, 7);
  });
}
