import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Detects two distinct strong movements in a short interval.
class ShakeDetection {
  static const double threshold = 12.0;
  static const double resetThreshold = 5.0;
  static const Duration peakWindow = Duration(milliseconds: 650);
  static const Duration cooldown = Duration(milliseconds: 1800);

  DateTime? _firstPeakAt;
  DateTime? _lastShakeAt;
  bool _readyForPeak = true;

  bool addSample(double x, double y, double z, DateTime now) {
    final magnitude = math.sqrt(x * x + y * y + z * z);
    if (!magnitude.isFinite) return false;

    if (magnitude <= resetThreshold) {
      _readyForPeak = true;
      return false;
    }
    if (magnitude < threshold || !_readyForPeak) return false;
    _readyForPeak = false;

    final lastShakeAt = _lastShakeAt;
    if (lastShakeAt != null && now.difference(lastShakeAt) < cooldown) {
      return false;
    }

    final firstPeakAt = _firstPeakAt;
    if (firstPeakAt == null || now.difference(firstPeakAt) > peakWindow) {
      _firstPeakAt = now;
      return false;
    }

    _firstPeakAt = null;
    _lastShakeAt = now;
    return true;
  }

  void reset() {
    _firstPeakAt = null;
    _readyForPeak = true;
  }
}

class ShakeDetectorService {
  final Stream<UserAccelerometerEvent> Function() _sensorEvents;
  final DateTime Function() _now;
  final bool Function() _platformSupported;
  final ShakeDetection _detection;
  final StreamController<void> _shakes = StreamController<void>.broadcast();

  StreamSubscription<UserAccelerometerEvent>? _subscription;
  bool _disposed = false;

  ShakeDetectorService({
    Stream<UserAccelerometerEvent> Function()? sensorEvents,
    DateTime Function()? now,
    bool Function()? platformSupported,
    ShakeDetection? detection,
  }) : _sensorEvents =
           sensorEvents ??
           (() => userAccelerometerEventStream(
             samplingPeriod: SensorInterval.uiInterval,
           )),
       _now = now ?? DateTime.now,
       _platformSupported =
           platformSupported ??
           (() =>
               !kIsWeb &&
               (defaultTargetPlatform == TargetPlatform.android ||
                   defaultTargetPlatform == TargetPlatform.iOS)),
       _detection = detection ?? ShakeDetection();

  Stream<void> get shakes => _shakes.stream;

  bool get isRunning => _subscription != null;

  void start() {
    if (_disposed || _subscription != null) return;
    if (!_platformSupported()) return;

    try {
      _subscription = _sensorEvents().listen(
        (event) {
          if (_detection.addSample(event.x, event.y, event.z, _now())) {
            _shakes.add(null);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('FinTracker shake sensor unavailable: $error');
          unawaited(stop());
        },
      );
    } catch (error) {
      debugPrint('FinTracker shake sensor unavailable: $error');
    }
  }

  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    _detection.reset();
    try {
      await subscription?.cancel();
    } catch (error) {
      debugPrint('FinTracker shake sensor stop error: $error');
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _shakes.close();
  }
}
