import 'dart:async';

import 'package:fin_tracker/data/services/shake_detector_service.dart';
import 'package:fin_tracker/presentation/controllers/shake_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final start = DateTime(2026, 1, 1);

  test('слабые движения не вызывают shake', () {
    final detector = ShakeDetection();
    for (var i = 0; i < 20; i++) {
      expect(
        detector.addSample(3, 2, 1, start.add(Duration(milliseconds: i * 40))),
        isFalse,
      );
    }
  });

  test('два сильных импульса вызывают один shake', () {
    final detector = ShakeDetection();
    expect(detector.addSample(13, 0, 0, start), isFalse);
    expect(
      detector.addSample(14, 0, 0, start.add(const Duration(milliseconds: 50))),
      isFalse,
    );
    expect(
      detector.addSample(0, 0, 0, start.add(const Duration(milliseconds: 100))),
      isFalse,
    );
    expect(
      detector.addSample(
        0,
        13,
        0,
        start.add(const Duration(milliseconds: 240)),
      ),
      isTrue,
    );
  });

  test('cooldown блокирует повторное событие', () {
    final detector = ShakeDetection();
    detector.addSample(13, 0, 0, start);
    detector.addSample(0, 0, 0, start.add(const Duration(milliseconds: 100)));
    expect(
      detector.addSample(
        13,
        0,
        0,
        start.add(const Duration(milliseconds: 200)),
      ),
      isTrue,
    );
    detector.addSample(0, 0, 0, start.add(const Duration(milliseconds: 300)));
    expect(
      detector.addSample(
        13,
        0,
        0,
        start.add(const Duration(milliseconds: 400)),
      ),
      isFalse,
    );
    detector.addSample(0, 0, 0, start.add(const Duration(milliseconds: 500)));
    expect(
      detector.addSample(
        13,
        0,
        0,
        start.add(const Duration(milliseconds: 600)),
      ),
      isFalse,
    );
  });

  test('после cooldown следующий shake снова разрешён', () {
    final detector = ShakeDetection();
    detector.addSample(13, 0, 0, start);
    detector.addSample(0, 0, 0, start.add(const Duration(milliseconds: 100)));
    expect(
      detector.addSample(
        13,
        0,
        0,
        start.add(const Duration(milliseconds: 200)),
      ),
      isTrue,
    );
    detector.addSample(0, 0, 0, start.add(const Duration(milliseconds: 2000)));
    expect(
      detector.addSample(
        13,
        0,
        0,
        start.add(const Duration(milliseconds: 2100)),
      ),
      isFalse,
    );
    detector.addSample(0, 0, 0, start.add(const Duration(milliseconds: 2200)));
    expect(
      detector.addSample(
        13,
        0,
        0,
        start.add(const Duration(milliseconds: 2300)),
      ),
      isTrue,
    );
  });

  test(
    'service cancels the raw sensor subscription on stop and dispose',
    () async {
      var cancellations = 0;
      final raw = StreamController<UserAccelerometerEvent>(
        onCancel: () => cancellations++,
      );
      final service = ShakeDetectorService(
        sensorEvents: () => raw.stream,
        platformSupported: () => true,
      );

      service.start();
      expect(service.isRunning, isTrue);
      await service.stop();
      expect(service.isRunning, isFalse);
      expect(cancellations, 1);
      await service.dispose();
      await raw.close();
    },
  );

  test('настройка по умолчанию включена и сохраняется', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = ShakeSettingsController();
    await settings.load();
    expect(settings.enabled, isTrue);

    await settings.setEnabled(false);
    final reloaded = ShakeSettingsController();
    await reloaded.load();
    expect(reloaded.enabled, isFalse);
  });
}
