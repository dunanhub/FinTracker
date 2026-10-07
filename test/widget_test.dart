import 'package:flutter_test/flutter_test.dart';

import 'package:fin_tracker/app.dart';
import 'package:fin_tracker/core/theme/theme_controller.dart';
import 'package:fin_tracker/presentation/controllers/finance_controller.dart';

void main() {
  testWidgets('FinTracker открывает главный экран', (
    WidgetTester tester,
  ) async {
    final themeController = ThemeController();

    final financeController = FinanceController();

    await tester.pumpWidget(
      FinTrackerApp(
        themeController: themeController,
        financeController: financeController,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Мои финансы'), findsOneWidget);

    expect(find.text('Общий баланс'), findsOneWidget);
  });
}
