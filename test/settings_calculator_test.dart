import 'package:fin_tracker/core/theme/app_theme.dart';
import 'package:fin_tracker/core/theme/theme_controller.dart';
import 'package:fin_tracker/core/theme/theme_preset.dart';
import 'package:fin_tracker/presentation/controllers/shake_settings_controller.dart';
import 'package:fin_tracker/presentation/screens/savings_calculator_screen.dart';
import 'package:fin_tracker/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('theme and shake preferences survive controller reload', () async {
    final theme = ThemeController();
    final shake = ShakeSettingsController();
    await theme.setPreset(AppThemePreset.pink);
    await theme.setThemeMode(ThemeMode.dark);
    await shake.setEnabled(false);

    final restoredTheme = ThemeController();
    final restoredShake = ShakeSettingsController();
    await restoredTheme.load();
    await restoredShake.load();
    expect(restoredTheme.preset, AppThemePreset.pink);
    expect(restoredTheme.themeMode, ThemeMode.dark);
    expect(restoredShake.enabled, isFalse);

    theme.dispose();
    shake.dispose();
    restoredTheme.dispose();
    restoredShake.dispose();
  });

  test('unknown saved theme names safely return to defaults', () async {
    SharedPreferences.setMockInitialValues({
      'theme_preset': 'removed-preset',
      'theme_mode': 'removed-mode',
    });
    final theme = ThemeController();
    await theme.load();
    expect(theme.preset, AppThemePreset.navy);
    expect(theme.themeMode, ThemeMode.system);
    theme.dispose();
  });

  testWidgets('settings shake switch changes saved preference', (tester) async {
    final theme = ThemeController();
    final shake = ShakeSettingsController();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeController>.value(value: theme),
          ChangeNotifierProvider<ShakeSettingsController>.value(value: shake),
        ],
        child: MaterialApp(
          theme: AppTheme.light(AppThemePreset.navy),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Встряхнуть для добавления'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final switchFinder = find.byType(SwitchListTile);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(shake.enabled, isFalse);
    expect(
      (await SharedPreferences.getInstance()).getBool('shake_to_add_enabled'),
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('calculator switches between contribution and deadline results', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(AppThemePreset.navy),
        home: const SavingsCalculatorScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '1000');
    await tester.enterText(find.byType(TextField).at(1), '400');
    final periodField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Количество месяцев',
    );
    await tester.scrollUntilVisible(
      periodField,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(periodField, '2');
    await tester.pumpAndSettle();
    expect(find.text('300 ₸'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Когда накоплю'),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Когда накоплю'));
    await tester.pumpAndSettle();
    final monthlyField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'В месяц',
    );
    await tester.scrollUntilVisible(
      monthlyField,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(monthlyField, '150');
    await tester.pumpAndSettle();
    expect(find.text('4 месяца'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Уже накоплено',
      ),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).at(1), '1000');
    await tester.pumpAndSettle();
    expect(find.text('Цель уже достигнута'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
