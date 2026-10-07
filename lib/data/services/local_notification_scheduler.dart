import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/app_notification.dart';
import '../../domain/services/reminder_policy.dart';

abstract class NotificationScheduler {
  Future<String?> initialize(void Function(String) onTap);
  Future<void> refreshTimezone();
  Future<void> schedule(AppNotification notification);
  Future<void> cancel(String id);
}

class LocalNotificationScheduler implements NotificationScheduler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<String?> initialize(void Function(String) onTap) async {
    if (!_supported) return null;
    await refreshTimezone();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_fintracker'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final id = response.payload;
        if (id != null && id.isNotEmpty) onTap(id);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    return launch?.didNotificationLaunchApp == true
        ? launch?.notificationResponse?.payload
        : null;
  }

  @override
  Future<void> refreshTimezone() async {
    if (!_supported) return;
    tz_data.initializeTimeZones();
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  }

  @override
  Future<void> schedule(AppNotification notification) async {
    if (!_supported) return;
    await _plugin.zonedSchedule(
      id: ReminderPolicy.notificationId(notification.id),
      title: notification.title,
      body: notification.body,
      scheduledDate: tz.TZDateTime.from(notification.scheduledAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'fintracker_deadlines',
          'Сроки долгов и целей',
          channelDescription: 'Напоминания о сроках финансовых обязательств',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: notification.id,
    );
  }

  @override
  Future<void> cancel(String id) async {
    if (!_supported) return;
    await _plugin.cancel(id: ReminderPolicy.notificationId(id));
  }
}
