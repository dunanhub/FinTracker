class NativeBatteryInfo {
  final int? level;
  final bool? isCharging;
  final String? source;

  const NativeBatteryInfo({this.level, this.isCharging, this.source});

  factory NativeBatteryInfo.fromPlatformMap(Map<dynamic, dynamic> map) {
    final rawLevel = map['level'];
    final rawCharging = map['isCharging'];
    final rawSource = map['source'];

    return NativeBatteryInfo(
      level:
          rawLevel is int && rawLevel >= 0 && rawLevel <= 100 ? rawLevel : null,
      isCharging: rawCharging is bool ? rawCharging : null,
      source: rawSource is String && rawSource.isNotEmpty ? rawSource : null,
    );
  }
}

class NativeDeviceInfo {
  final String? manufacturer;
  final String? model;
  final String? androidVersion;
  final int? sdkInt;

  const NativeDeviceInfo({
    this.manufacturer,
    this.model,
    this.androidVersion,
    this.sdkInt,
  });

  factory NativeDeviceInfo.fromPlatformMap(Map<dynamic, dynamic> map) {
    String? nonEmptyString(Object? value) =>
        value is String && value.trim().isNotEmpty ? value : null;

    return NativeDeviceInfo(
      manufacturer: nonEmptyString(map['manufacturer']),
      model: nonEmptyString(map['model']),
      androidVersion: nonEmptyString(map['androidVersion']),
      sdkInt: map['sdkInt'] is int ? map['sdkInt'] as int : null,
    );
  }
}
