package com.example.fin_tracker

import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getBatteryInfo" -> {
                            val battery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                            if (battery == null) {
                                result.error("BATTERY_UNAVAILABLE", "Battery information is unavailable", null)
                            } else {
                                val level = battery.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                                val scale = battery.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                                val percentage = if (level >= 0 && scale > 0) {
                                    (level * 100 / scale).coerceIn(0, 100)
                                } else {
                                    null
                                }
                                val status = battery.getIntExtra(BatteryManager.EXTRA_STATUS, -1)
                                val isCharging = when (status) {
                                    BatteryManager.BATTERY_STATUS_CHARGING,
                                    BatteryManager.BATTERY_STATUS_FULL -> true
                                    BatteryManager.BATTERY_STATUS_DISCHARGING,
                                    BatteryManager.BATTERY_STATUS_NOT_CHARGING -> false
                                    else -> null
                                }
                                val source = when (battery.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)) {
                                    BatteryManager.BATTERY_PLUGGED_AC -> "ac"
                                    BatteryManager.BATTERY_PLUGGED_USB -> "usb"
                                    BatteryManager.BATTERY_PLUGGED_WIRELESS -> "wireless"
                                    BatteryManager.BATTERY_PLUGGED_DOCK -> "dock"
                                    0 -> "battery"
                                    else -> null
                                }
                                result.success(mapOf("level" to percentage, "isCharging" to isCharging, "source" to source))
                            }
                        }
                        "getDeviceInfo" -> result.success(
                            mapOf(
                                "manufacturer" to Build.MANUFACTURER,
                                "model" to Build.MODEL,
                                "androidVersion" to Build.VERSION.RELEASE,
                                "sdkInt" to Build.VERSION.SDK_INT,
                            )
                        )
                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error("NATIVE_DEVICE_ERROR", error.message ?: "Unable to read device information", null)
                }
            }
    }

    companion object {
        private const val CHANNEL_NAME = "com.example.fin_tracker/native_device"
    }
}
