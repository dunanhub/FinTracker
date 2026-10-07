import 'package:fin_tracker/core/theme/app_theme.dart';
import 'package:fin_tracker/core/theme/theme_preset.dart';
import 'package:fin_tracker/domain/entities/account.dart';
import 'package:fin_tracker/domain/entities/finance_transaction.dart';
import 'package:fin_tracker/domain/repositories/finance_repository.dart';
import 'package:fin_tracker/presentation/controllers/budget_controller.dart';
import 'package:fin_tracker/presentation/controllers/finance_controller.dart';
import 'package:fin_tracker/presentation/controllers/notification_center_controller.dart';
import 'package:fin_tracker/presentation/screens/dashboard_screen.dart';
import 'package:fin_tracker/presentation/widgets/smooth_line_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class _SeededFinanceRepository implements FinanceRepository {
  List<Account> accounts;
  List<FinanceTransaction> transactions;

  _SeededFinanceRepository(
    this.accounts, {
    this.transactions = const <FinanceTransaction>[],
  });

  @override
  Future<FinanceStorageData> load() async =>
      FinanceStorageData(transactions: transactions, accounts: accounts);

  @override
  Future<void> save({
    required List<FinanceTransaction> transactions,
    required List<Account> accounts,
  }) async {}
}

Future<GoRouter> _showDashboard(
  WidgetTester tester, {
  required FinanceController finance,
  required ThemeData theme,
  double textScale = 1,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: DashboardScreen()),
      ),
      GoRoute(
        path: '/notifications',
        builder: (_, _) => const Scaffold(body: Text('История уведомлений')),
      ),
    ],
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<FinanceController>.value(value: finance),
        ChangeNotifierProvider<BudgetController>.value(
          value: BudgetController(),
        ),
        Provider<NotificationCenterController?>.value(value: null),
      ],
      child: MaterialApp.router(
        theme: theme,
        routerConfig: router,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('dashboard remains usable in every palette on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final finance = FinanceController();
    for (final preset in AppThemePreset.values) {
      for (final dark in [false, true]) {
        final router = await _showDashboard(
          tester,
          finance: finance,
          theme: dark ? AppTheme.dark(preset) : AppTheme.light(preset),
        );
        expect(find.text('Мои финансы'), findsOneWidget);
        expect(find.text('Общий баланс'), findsOneWidget);
        expect(tester.takeException(), isNull);
        router.dispose();
      }
    }
  });

  testWidgets('empty dashboard keeps its sections and chart', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final finance = FinanceController(repository: _SeededFinanceRepository([]));
    await finance.load();
    final router = await _showDashboard(
      tester,
      finance: finance,
      theme: AppTheme.light(AppThemePreset.navy),
    );
    expect(find.text('Добавь первый счёт'), findsOneWidget);
    expect(find.byType(SmoothLineChart), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1100),
    );
    await tester.pumpAndSettle();
    expect(find.text('Пока нет операций'), findsOneWidget);
    expect(tester.takeException(), isNull);
    router.dispose();
  });

  testWidgets('dashboard supports enlarged text on a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = await _showDashboard(
      tester,
      finance: FinanceController(),
      theme: AppTheme.dark(AppThemePreset.navy),
      textScale: 1.5,
    );
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    router.dispose();
  });

  testWidgets(
    'account deck aligns edge cards and retains selection as accounts change',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const first = Account(
        id: 'first',
        name: 'Первый счёт',
        type: AccountType.card,
        balance: 12345,
      );
      const second = Account(
        id: 'second',
        name: 'Второй счёт',
        type: AccountType.cash,
        balance: 2000,
      );
      const third = Account(
        id: 'third',
        name: 'Третий счёт',
        type: AccountType.deposit,
        balance: 3000,
      );
      final repository = _SeededFinanceRepository([first]);
      final finance = FinanceController(repository: repository);
      await finance.load();
      final router = await _showDashboard(
        tester,
        finance: finance,
        theme: AppTheme.light(AppThemePreset.navy),
      );

      final singleCard =
          find
              .ancestor(
                of: find.text('Первый счёт'),
                matching: find.byType(Container),
              )
              .first;
      expect(tester.getSize(singleCard).width, 320);
      expect(find.byType(PageView), findsNothing);

      repository.accounts = [first, second, third];
      await finance.load();
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsNothing);
      expect(find.byType(PageView), findsOneWidget);
      final balanceCard =
          find
              .ancestor(
                of: find.text('Общий баланс'),
                matching: find.byType(Container),
              )
              .first;
      final pageCard =
          find
              .ancestor(
                of: find.text('Первый счёт'),
                matching: find.byType(Container),
              )
              .first;
      expect(tester.getRect(pageCard).left, tester.getRect(balanceCard).left);
      final iconTile =
          find
              .ancestor(
                of: find.byIcon(Icons.credit_card_rounded),
                matching: find.byType(Container),
              )
              .first;
      expect(
        tester.getRect(find.text('Карта')).left,
        tester.getRect(iconTile).left,
      );
      expect(
        tester.getRect(find.text('Карта')).left,
        lessThan(tester.getRect(find.text('Первый счёт')).left),
      );
      final nextPreview = find.byKey(const Key('dashboard_account_second'));
      expect(find.byKey(const Key('dashboard_account_second')), findsOneWidget);
      expect(tester.getRect(nextPreview).width, tester.getRect(pageCard).width);
      expect(tester.getRect(nextPreview).top, tester.getRect(pageCard).top);
      expect(
        tester.getRect(nextPreview).left,
        greaterThan(tester.getRect(pageCard).right),
      );

      for (final width in [320.0, 474.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpAndSettle();
        final heroRect = tester.getRect(balanceCard);
        final cardRect = tester.getRect(pageCard);
        final previewRect = tester.getRect(nextPreview);
        final peek = (heroRect.width * 0.105).clamp(28.0, 44.0);
        expect(cardRect.left, heroRect.left);
        expect(heroRect.right - cardRect.right, closeTo(peek, 1));
        expect(previewRect.left, greaterThan(cardRect.right));
        expect(previewRect.left, lessThan(heroRect.right));
        expect(previewRect.top, cardRect.top);
      }
      await tester.binding.setSurfaceSize(const Size(360, 800));
      await tester.pumpAndSettle();

      final initialNextLeft = tester.getRect(nextPreview).left;
      final swipe = await tester.startGesture(
        tester.getCenter(find.byType(PageView)),
      );
      await swipe.moveBy(const Offset(-20, 0));
      await swipe.moveBy(const Offset(-100, 0));
      await tester.pump();
      expect(find.byKey(const Key('dashboard_account_first')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_account_second')), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('dashboard_account_second'))).left,
        lessThan(initialNextLeft),
      );
      await swipe.moveBy(const Offset(-180, 0));
      await swipe.up();
      await tester.pumpAndSettle();
      expect(find.text('Второй счёт'), findsOneWidget);
      final middleCard =
          find
              .ancestor(
                of: find.text('Второй счёт'),
                matching: find.byType(Container),
              )
              .first;
      final leftPeek = find.byKey(const Key('dashboard_account_first'));
      final rightPeek = find.byKey(const Key('dashboard_account_third'));
      expect(
        tester.getRect(leftPeek).right,
        lessThan(tester.getRect(middleCard).left),
      );
      expect(
        tester.getRect(leftPeek).right,
        greaterThan(tester.getRect(balanceCard).left),
      );
      expect(
        tester.getRect(rightPeek).left,
        greaterThan(tester.getRect(middleCard).right),
      );
      expect(
        tester.getRect(rightPeek).left,
        lessThan(tester.getRect(balanceCard).right),
      );

      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      final lastCard =
          find
              .ancestor(
                of: find.text('Третий счёт'),
                matching: find.byType(Container),
              )
              .first;
      expect(tester.getRect(lastCard).right, tester.getRect(balanceCard).right);
      final previousPreview = find.byKey(const Key('dashboard_account_second'));
      expect(
        tester.getRect(previousPreview).right,
        lessThan(tester.getRect(lastCard).left),
      );
      expect(tester.getRect(previousPreview).top, tester.getRect(lastCard).top);

      repository.accounts = [first, third];
      await finance.load();
      await tester.pumpAndSettle();
      expect(find.text('Третий счёт'), findsOneWidget);

      repository.accounts = [third];
      await finance.load();
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Третий счёт'), findsOneWidget);

      repository.accounts = [first, third];
      await finance.load();
      await tester.pumpAndSettle();
      expect(find.text('Третий счёт'), findsOneWidget);
      expect(tester.takeException(), isNull);
      router.dispose();
    },
  );

  testWidgets('account expense badge reacts to lower and higher spending', (
    tester,
  ) async {
    final now = DateTime.now();
    const account = Account(
      id: 'cash',
      name: 'Наличные',
      type: AccountType.cash,
      balance: 5000,
    );
    FinanceTransaction expense(String id, DateTime date, double amount) =>
        FinanceTransaction(
          id: id,
          type: FinanceTransactionType.expense,
          amount: amount,
          accountId: 'cash',
          title: id,
          date: date,
        );
    final repository = _SeededFinanceRepository(
      [account],
      transactions: [
        expense('previous', DateTime(now.year, now.month - 1, 1), 200),
        expense('current', DateTime(now.year, now.month, 1), 100),
      ],
    );
    final finance = FinanceController(repository: repository);
    await finance.load();
    final router = await _showDashboard(
      tester,
      finance: finance,
      theme: AppTheme.light(AppThemePreset.navy),
    );
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.byIcon(Icons.south_rounded), findsOneWidget);

    repository.transactions = [
      expense('previous', DateTime(now.year, now.month - 1, 1), 200),
      expense('current', DateTime(now.year, now.month, 1), 300),
    ];
    await finance.load();
    await tester.pumpAndSettle();
    expect(find.text('50.0%'), findsOneWidget);
    expect(find.byIcon(Icons.north_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
    router.dispose();
  });

  testWidgets('dashboard links still open notifications and accounts', (
    tester,
  ) async {
    final router = await _showDashboard(
      tester,
      finance: FinanceController(),
      theme: AppTheme.light(AppThemePreset.navy),
    );
    await tester.tap(find.byTooltip('Уведомления'));
    await tester.pumpAndSettle();
    expect(find.text('История уведомлений'), findsOneWidget);
    router.go('/');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Все счета'));
    await tester.pumpAndSettle();
    expect(find.text('Счета'), findsOneWidget);
    expect(tester.takeException(), isNull);
    router.dispose();
  });
}
