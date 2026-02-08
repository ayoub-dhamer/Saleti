import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

/// 🔔 Background alarm callback (NO foreground service)
@pragma('vm:entry-point')
Future<void> reminderCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);

  await _notifications.initialize(settings);

  await _notifications.show(
    id,
    params['title'],
    params['body'],
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_reminder_channel',
        'Prayer Reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: false, // 🔕 silent reminder
      ),
    ),
  );
}

class PrayerReminderService {
  /// Call once in main()
  static Future<void> init() async {
    await AndroidAlarmManager.initialize();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notifications.initialize(settings);

    const channel = AndroidNotificationChannel(
      'prayer_reminder_channel',
      'Prayer Reminders',
      description: 'Silent prayer reminders',
      importance: Importance.high,
      playSound: false,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(channel);
  }

  /// Schedule reminder (e.g. 10 minutes before prayer)
  static Future<void> scheduleReminder({
    required int id,
    required DateTime prayerTime,
    required String prayerName,
    required int minutesBefore,
  }) async {
    final reminderTime = prayerTime.subtract(Duration(minutes: minutesBefore));

    if (reminderTime.isBefore(DateTime.now())) return;

    await AndroidAlarmManager.oneShotAt(
      reminderTime,
      id,
      reminderCallback,
      exact: true,
      wakeup: true,
      params: {
        'title': 'Prayer Reminder',
        'body': '$prayerName in $minutesBefore minutes',
        'playAzan': false, // ✅ EXPLICIT
      },
    );
  }

  /// Cancel reminder
  static Future<void> cancel(int id) async {
    await AndroidAlarmManager.cancel(id);
  }
}
