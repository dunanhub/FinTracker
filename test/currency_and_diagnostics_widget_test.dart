import 'dart:async';

import 'package:fin_tracker/core/theme/app_theme.dart';
import 'package:fin_tracker/core/theme/theme_preset.dart';
import 'package:fin_tracker/domain/entities/currency_rate.dart';
import 'package:fin_tracker/domain/entities/native_device_info.dart';
import 'package:fin_tracker/domain/repositories/currency_repository.dart';
import 'package:fin_tracker/domain/repositories/native_device_repository.dart';
import 'package:fin_tracker/presentation/providers/currency_rates_provider.dart';
import 'package:fin_tracker/presentation/screens/currency_rates_screen.dart';
import 'package:fin_tracker/presentation/screens/device_diagnostics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _CurrencyFake implements CurrencyRepository {
  Future<List<CurrencyRate>> Function() response;
  int calls = 0;

  _CurrencyFake(this.response);

  @override
  Future<List<CurrencyRate>> fetchRates() {
    calls++;
    return response();
  }
}

class _DeviceFake implements NativeDeviceRepository {
  @override
  bool isSupported = true;
  Object? error;

  @override
  Future<NativeBatteryInfo> getBatteryInfo() async {
    if (error != null) throw error!;
    return const NativeBatteryInfo(level: 84, isCharging: true, source: 'usb');
  }

  @override
  Future<NativeDeviceInfo> getDeviceInfo() async {
    if (error != null) throw error!;
    return const NativeDeviceInfo(
      manufacturer: 'Google',
      model: 'Pixel 8',
      androidVersion: '15',
      sdkInt: 35,
    );
  }
}

Future<void> _showCurrency(
  WidgetTester tester,
  _CurrencyFake repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currencyRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        theme: AppTheme.light(AppThemePreset.navy),
        home: const CurrencyRatesScreen(),
      ),
    ),
  );
}

void main() {
  final rate = CurrencyRate(
    code: 'USD',
    name: 'US Dollar',
    symbol: r'$',
    rateToKzt: 540,
    date: DateTime(2026, 10, 5),
  );

  testWidgets('currency screen loads and converts after data arrives', (
    tester,
  ) async {
    final pending = Completer<List<CurrencyRate>>();
    final repository = _CurrencyFake(() => pending.future);
    await _showCurrency(tester, repository);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    pending.complete([rate]);
    await tester.pumpAndSettle();
    expect(find.text('Конвертер'), findsOneWidget);
    expect(find.text('US Dollar'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '2');
    await tester.pump();
    expect(find.text('1 080,00 ₸'), findsOneWidget);
    expect(repository.calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('currency error retry recovers without network', (tester) async {
    final repository = _CurrencyFake(() async => throw Exception('offline'));
    await _showCurrency(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить'), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    repository.response = () async => [rate];
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Конвертер'), findsOneWidget);
    expect(repository.calls, 2);
  });

  testWidgets('device screen shows Android values and unsupported state', (
    tester,
  ) async {
    final repository = _DeviceFake();
    await tester.pumpWidget(
      MaterialApp(home: DeviceDiagnosticsPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pixel 8'), findsOneWidget);
    expect(find.text('84%'), findsOneWidget);
    expect(find.text('USB'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    repository.isSupported = false;
    await tester.pumpWidget(
      MaterialApp(home: DeviceDiagnosticsPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Нативная диагностика доступна только на Android'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('device screen reports repository failures', (tester) async {
    final repository =
        _DeviceFake()
          ..error = PlatformException(
            code: 'BATTERY_UNAVAILABLE',
            message: 'Battery unavailable',
          );
    await tester.pumpWidget(
      MaterialApp(home: DeviceDiagnosticsPage(repository: repository)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Battery unavailable'), findsOneWidget);
    expect(find.text('Обновить данные'), findsOneWidget);
  });
}
