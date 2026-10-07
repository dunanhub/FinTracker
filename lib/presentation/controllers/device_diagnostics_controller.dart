import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/native_device_info.dart';
import '../../domain/repositories/native_device_repository.dart';
import '../../data/services/crash_reporting_service.dart';

enum DeviceDiagnosticsStatus { initial, loading, loaded, error, unsupported }

class DeviceDiagnosticsController extends ChangeNotifier {
  final NativeDeviceRepository repository;
  final CrashReportingService? crashReporting;

  DeviceDiagnosticsController({required this.repository, this.crashReporting});

  DeviceDiagnosticsStatus _status = DeviceDiagnosticsStatus.initial;
  NativeBatteryInfo? _battery;
  NativeDeviceInfo? _device;
  String? _errorMessage;

  DeviceDiagnosticsStatus get status => _status;
  NativeBatteryInfo? get battery => _battery;
  NativeDeviceInfo? get device => _device;
  String? get errorMessage => _errorMessage;
  bool get canSendTestError => crashReporting?.supported ?? false;

  Future<CrashReportResult> sendTestError() async =>
      await crashReporting?.sendTestNonFatal() ?? CrashReportResult.unsupported;

  Future<void> refresh() async {
    if (_status == DeviceDiagnosticsStatus.loading) return;

    if (!repository.isSupported) {
      _status = DeviceDiagnosticsStatus.unsupported;
      notifyListeners();
      return;
    }

    _status = DeviceDiagnosticsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final device = await repository.getDeviceInfo();
      final battery = await repository.getBatteryInfo();
      _device = device;
      _battery = battery;
      _status = DeviceDiagnosticsStatus.loaded;
    } on PlatformException catch (error) {
      _status = DeviceDiagnosticsStatus.error;
      _errorMessage = error.message ?? 'Не удалось получить данные устройства.';
    } catch (_) {
      _status = DeviceDiagnosticsStatus.error;
      _errorMessage = 'Не удалось получить данные устройства.';
    }
    notifyListeners();
  }
}
