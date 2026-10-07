import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/native_device_info.dart';
import '../../domain/repositories/native_device_repository.dart';

class PlatformNativeDeviceRepository implements NativeDeviceRepository {
  static const channelName = 'com.example.fin_tracker/native_device';

  final MethodChannel _channel;
  final bool Function() _platformSupported;

  PlatformNativeDeviceRepository({
    MethodChannel? channel,
    bool Function()? platformSupported,
  }) : _channel = channel ?? const MethodChannel(channelName),
       _platformSupported =
           platformSupported ??
           (() => !kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  @override
  bool get isSupported => _platformSupported();

  @override
  Future<NativeBatteryInfo> getBatteryInfo() async {
    if (!isSupported) {
      throw UnsupportedError('Native diagnostics require Android.');
    }
    final response = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getBatteryInfo',
    );
    if (response == null) {
      throw const FormatException('Нет данных о батарее.');
    }
    return NativeBatteryInfo.fromPlatformMap(response);
  }

  @override
  Future<NativeDeviceInfo> getDeviceInfo() async {
    if (!isSupported) {
      throw UnsupportedError('Native diagnostics require Android.');
    }
    final response = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getDeviceInfo',
    );
    if (response == null) {
      throw const FormatException('Нет данных об устройстве.');
    }
    return NativeDeviceInfo.fromPlatformMap(response);
  }
}
