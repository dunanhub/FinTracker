import 'package:fin_tracker/data/repositories/platform_native_device_repository.dart';
import 'package:fin_tracker/domain/entities/native_device_info.dart';
import 'package:fin_tracker/domain/repositories/native_device_repository.dart';
import 'package:fin_tracker/presentation/controllers/device_diagnostics_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeNativeDeviceRepository implements NativeDeviceRepository {
  @override
  bool isSupported = true;

  NativeBatteryInfo battery = const NativeBatteryInfo(
    level: 84,
    isCharging: true,
    source: 'usb',
  );
  NativeDeviceInfo device = const NativeDeviceInfo(
    manufacturer: 'Google',
    model: 'Pixel 8',
    androidVersion: '15',
    sdkInt: 35,
  );
  Object? error;
  int batteryCalls = 0;
  int deviceCalls = 0;

  @override
  Future<NativeBatteryInfo> getBatteryInfo() async {
    batteryCalls++;
    if (error != null) throw error!;
    return battery;
  }

  @override
  Future<NativeDeviceInfo> getDeviceInfo() async {
    deviceCalls++;
    if (error != null) throw error!;
    return device;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('fin_tracker_test/native_device');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('parses battery response from MethodChannel', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getBatteryInfo');
      return {'level': 84, 'isCharging': true, 'source': 'usb'};
    });

    final repository = PlatformNativeDeviceRepository(
      channel: channel,
      platformSupported: () => true,
    );
    final battery = await repository.getBatteryInfo();

    expect(battery.level, 84);
    expect(battery.isCharging, isTrue);
    expect(battery.source, 'usb');
  });

  test('parses device response from MethodChannel', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getDeviceInfo');
      return {
        'manufacturer': 'Google',
        'model': 'Pixel 8',
        'androidVersion': '15',
        'sdkInt': 35,
      };
    });

    final repository = PlatformNativeDeviceRepository(
      channel: channel,
      platformSupported: () => true,
    );
    final device = await repository.getDeviceInfo();

    expect(device.manufacturer, 'Google');
    expect(device.model, 'Pixel 8');
    expect(device.androidVersion, '15');
    expect(device.sdkInt, 35);
  });

  test('PlatformException becomes error state', () async {
    final repository =
        _FakeNativeDeviceRepository()
          ..error = PlatformException(
            code: 'BATTERY_UNAVAILABLE',
            message: 'Battery information is unavailable',
          );
    final controller = DeviceDiagnosticsController(repository: repository);

    await controller.refresh();

    expect(controller.status, DeviceDiagnosticsStatus.error);
    expect(controller.errorMessage, 'Battery information is unavailable');
    controller.dispose();
  });

  test('unsupported platform does not call native repository', () async {
    final repository = _FakeNativeDeviceRepository()..isSupported = false;
    final controller = DeviceDiagnosticsController(repository: repository);

    await controller.refresh();

    expect(controller.status, DeviceDiagnosticsStatus.unsupported);
    expect(repository.deviceCalls, 0);
    expect(repository.batteryCalls, 0);
    controller.dispose();
  });

  test('repository skips MethodChannel on unsupported platform', () async {
    final repository = PlatformNativeDeviceRepository(
      channel: channel,
      platformSupported: () => false,
    );

    await expectLater(repository.getDeviceInfo(), throwsUnsupportedError);
    await expectLater(repository.getBatteryInfo(), throwsUnsupportedError);
  });

  test('refresh replaces previously loaded values', () async {
    final repository = _FakeNativeDeviceRepository();
    final controller = DeviceDiagnosticsController(repository: repository);

    await controller.refresh();
    expect(controller.status, DeviceDiagnosticsStatus.loaded);
    expect(controller.battery?.level, 84);

    repository.battery = const NativeBatteryInfo(
      level: 55,
      isCharging: false,
      source: 'battery',
    );
    await controller.refresh();

    expect(controller.status, DeviceDiagnosticsStatus.loaded);
    expect(controller.battery?.level, 55);
    expect(controller.battery?.isCharging, isFalse);
    expect(repository.batteryCalls, 2);
    controller.dispose();
  });
}
