import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

enum CrashReportResult { queued, unsupported, unavailable }

abstract class CrashReporter {
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> recordFlutterFatalError(FlutterErrorDetails details);
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    required bool fatal,
  });
  Future<void> sendUnsentReports();
}

class FirebaseCrashReporter implements CrashReporter {
  @override
  Future<void> setCollectionEnabled(bool enabled) =>
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);

  @override
  Future<void> recordFlutterFatalError(FlutterErrorDetails details) =>
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);

  @override
  Future<void> recordError(
    Object error,
    StackTrace stack, {
    required bool fatal,
  }) => FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);

  @override
  Future<void> sendUnsentReports() =>
      FirebaseCrashlytics.instance.sendUnsentReports();
}

class CrashReportingService {
  final CrashReporter _reporter;
  final bool supported;
  final bool automaticCollectionEnabled;
  bool _ready = false;

  CrashReportingService({
    CrashReporter? reporter,
    bool? supported,
    bool? automaticCollectionEnabled,
  }) : _reporter = reporter ?? FirebaseCrashReporter(),
       supported =
           supported ??
           (!kIsWeb && defaultTargetPlatform == TargetPlatform.android),
       automaticCollectionEnabled = automaticCollectionEnabled ?? !kDebugMode;

  bool get isAvailable => supported && _ready;
  bool get _canReportAutomatically => isAvailable && automaticCollectionEnabled;

  Future<void> initialize() async {
    if (!supported) return;
    try {
      await _reporter.setCollectionEnabled(automaticCollectionEnabled);
      _ready = true;
    } catch (_) {
      // Crash reporting is optional; startup and other features continue.
      _ready = false;
    }
  }

  /// Returns a cleanup callback so tests can restore process-wide handlers.
  VoidCallback installGlobalHandlers() {
    final previousFlutterHandler = FlutterError.onError;
    final previousPlatformHandler = PlatformDispatcher.instance.onError;

    FlutterError.onError = (details) {
      previousFlutterHandler?.call(details);
      unawaited(recordFlutterFatal(details));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      if (_canReportAutomatically) {
        unawaited(recordError(error, stack, fatal: true));
        return true;
      }
      return previousPlatformHandler?.call(error, stack) ?? false;
    };

    return () {
      FlutterError.onError = previousFlutterHandler;
      PlatformDispatcher.instance.onError = previousPlatformHandler;
    };
  }

  Future<void> recordFlutterFatal(FlutterErrorDetails details) async {
    if (!_canReportAutomatically) return;
    try {
      await _reporter.recordFlutterFatalError(
        FlutterErrorDetails(
          exception: StateError(
            'Unhandled Flutter error (${details.exception.runtimeType})',
          ),
          stack: details.stack,
        ),
      );
    } catch (_) {
      // Reporting failures must never become uncaught application errors.
    }
  }

  Future<void> recordError(
    Object error,
    StackTrace stack, {
    required bool fatal,
  }) async {
    if (!_canReportAutomatically) return;
    try {
      await _reporter.recordError(
        StateError('Unhandled Dart error (${error.runtimeType})'),
        stack,
        fatal: fatal,
      );
    } catch (_) {
      // Reporting failures must never become uncaught application errors.
    }
  }

  Future<CrashReportResult> sendTestNonFatal() async {
    if (!supported) return CrashReportResult.unsupported;
    if (!_ready) return CrashReportResult.unavailable;
    try {
      await _reporter.recordError(
        StateError('FinTracker diagnostics test (non-fatal)'),
        StackTrace.current,
        fatal: false,
      );
      // A manual send also flushes any older reports queued on this device.
      await _reporter.sendUnsentReports();
      return CrashReportResult.queued;
    } catch (_) {
      return CrashReportResult.unavailable;
    }
  }
}
