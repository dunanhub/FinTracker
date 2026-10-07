import 'package:fin_tracker/data/services/crash_reporting_service.dart';
import 'package:fin_tracker/domain/entities/native_device_info.dart';
import 'package:fin_tracker/domain/repositories/native_device_repository.dart';
import 'package:fin_tracker/presentation/screens/device_diagnostics_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCrashReporter implements CrashReporter {
  bool? collectionEnabled;
  int flutterFatalCalls = 0;
  int errorCalls = 0;
  int sendCalls = 0;
  bool? lastFatal;
  Object? lastError;
  bool fail = false;

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    if (fail) throw StateError('Reporter unavailable');
    collectionEnabled = enabled;
  }

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) async {
    if (fail) throw StateError('Reporter unavailable');
    flutterFatalCalls++;
    lastError = details.exception;
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    required bool fatal,
  }) async {
    if (fail) throw StateError('Reporter unavailable');
    errorCalls++;
    lastFatal = fatal;
    lastError = error;
  }

  @override
  Future<void> sendUnsentReports() async {
    if (fail) throw StateError('Reporter unavailable');
    sendCalls++;
  }
}

class _UnsupportedDevice implements NativeDeviceRepository {
  @override
  bool get isSupported => false;

  @override
  Future<NativeBatteryInfo> getBatteryInfo() => throw UnimplementedError();

  @override
  Future<NativeDeviceInfo> getDeviceInfo() => throw UnimplementedError();
}

void main() {
  test(
    'debug collection is disabled and global errors are not recorded',
    () async {
      final reporter = _FakeCrashReporter();
      final service = CrashReportingService(
        reporter: reporter,
        supported: true,
        automaticCollectionEnabled: false,
      );
      await service.initialize();
      expect(reporter.collectionEnabled, isFalse);
      await service.recordFlutterFatal(
        FlutterErrorDetails(exception: StateError('test')),
      );
      await service.recordError(
        StateError('test'),
        StackTrace.current,
        fatal: true,
      );
      expect(reporter.flutterFatalCalls, 0);
      expect(reporter.errorCalls, 0);
    },
  );

  test('enabled reporter receives Flutter and Dart errors', () async {
    final reporter = _FakeCrashReporter();
    final service = CrashReportingService(
      reporter: reporter,
      supported: true,
      automaticCollectionEnabled: true,
    );
    await service.initialize();
    expect(reporter.collectionEnabled, isTrue);
    await service.recordFlutterFatal(
      FlutterErrorDetails(exception: StateError('framework')),
    );
    await service.recordError(
      StateError('async'),
      StackTrace.current,
      fatal: true,
    );
    expect(reporter.flutterFatalCalls, 1);
    expect(reporter.errorCalls, 1);
    expect(reporter.lastFatal, isTrue);
  });

  test('automatic reports omit sensitive exception messages', () async {
    final reporter = _FakeCrashReporter();
    final service = CrashReportingService(
      reporter: reporter,
      supported: true,
      automaticCollectionEnabled: true,
    );
    await service.initialize();
    await service.recordFlutterFatal(
      FlutterErrorDetails(
        exception: StateError('admin@example.com /receipts/a'),
      ),
    );
    expect(reporter.lastError.toString(), isNot(contains('admin@example.com')));
    await service.recordError(
      StateError('account 123 /receipts/a'),
      StackTrace.current,
      fatal: true,
    );
    expect(reporter.lastError.toString(), isNot(contains('account 123')));
    expect(reporter.lastError.toString(), isNot(contains('/receipts/')));
  });

  test(
    'global handlers forward uncaught framework and platform errors',
    () async {
      final reporter = _FakeCrashReporter();
      final service = CrashReportingService(
        reporter: reporter,
        supported: true,
        automaticCollectionEnabled: true,
      );
      await service.initialize();
      final originalFlutterHandler = FlutterError.onError;
      FlutterError.onError = (_) {};
      final restore = service.installGlobalHandlers();
      addTearDown(() {
        restore();
        FlutterError.onError = originalFlutterHandler;
      });

      FlutterError.onError!(
        FlutterErrorDetails(exception: StateError('frame')),
      );
      final handled = PlatformDispatcher.instance.onError!(
        StateError('async'),
        StackTrace.current,
      );
      await Future<void>.delayed(Duration.zero);
      expect(handled, isTrue);
      expect(reporter.flutterFatalCalls, 1);
      expect(reporter.errorCalls, 1);
    },
  );

  test('unsupported platform avoids the reporter', () async {
    final reporter = _FakeCrashReporter();
    final service = CrashReportingService(
      reporter: reporter,
      supported: false,
      automaticCollectionEnabled: true,
    );
    await service.initialize();
    expect(service.isAvailable, isFalse);
    expect(await service.sendTestNonFatal(), CrashReportResult.unsupported);
    expect(reporter.collectionEnabled, isNull);
    expect(reporter.errorCalls, 0);
  });

  test('reporter failure does not escape service or block startup', () async {
    final reporter = _FakeCrashReporter()..fail = true;
    final service = CrashReportingService(
      reporter: reporter,
      supported: true,
      automaticCollectionEnabled: true,
    );
    await service.initialize();
    expect(service.isAvailable, isFalse);
    expect(await service.sendTestNonFatal(), CrashReportResult.unavailable);

    reporter.fail = false;
    await service.initialize();
    reporter.fail = true;
    await service.recordError(
      StateError('test'),
      StackTrace.current,
      fatal: true,
    );
    await service.recordFlutterFatal(
      FlutterErrorDetails(exception: StateError('test')),
    );
    expect(await service.sendTestNonFatal(), CrashReportResult.unavailable);
  });

  testWidgets('diagnostics button queues a non-fatal report through service', (
    tester,
  ) async {
    final reporter = _FakeCrashReporter();
    final service = CrashReportingService(
      reporter: reporter,
      supported: true,
      automaticCollectionEnabled: false,
    );
    await service.initialize();
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceDiagnosticsPage(
          repository: _UnsupportedDevice(),
          crashReporting: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.text('Отправить тестовую ошибку');
    await tester.scrollUntilVisible(button, 200);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(reporter.errorCalls, 1);
    expect(reporter.lastFatal, isFalse);
    expect(reporter.sendCalls, 1);
    expect(find.textContaining('Тестовый отчёт поставлен'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diagnostics reports failed upload without crashing', (
    tester,
  ) async {
    final reporter = _FakeCrashReporter();
    final service = CrashReportingService(
      reporter: reporter,
      supported: true,
      automaticCollectionEnabled: false,
    );
    await service.initialize();
    reporter.fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceDiagnosticsPage(
          repository: _UnsupportedDevice(),
          crashReporting: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.text('Отправить тестовую ошибку');
    await tester.scrollUntilVisible(button, 200);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Не удалось отправить тестовый отчёт'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
