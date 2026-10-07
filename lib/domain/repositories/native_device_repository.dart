import '../entities/native_device_info.dart';

abstract class NativeDeviceRepository {
  bool get isSupported;

  Future<NativeBatteryInfo> getBatteryInfo();

  Future<NativeDeviceInfo> getDeviceInfo();
}
