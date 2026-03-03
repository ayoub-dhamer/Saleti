import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_rescheduler.dart';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> alarmCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final notifications = FlutterLocalNotificationsPlugin();

  await notifications.initialize(
    const InitializationSettings(android: androidInit),
  );

  final bool isAzan = params['playAzan'] == true;

  if (isAzan) {
    // 🔊 SYSTEM ALARM (Android 16 SAFE)
    await notifications.show(
      id,
      params['title'] ?? 'Prayer Time',
      params['body'] ?? 'It is time for Salah',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'azan_channel',
          'Azan Notifications',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('azan'),
          visibility: NotificationVisibility.public,
        ),
      ),
    );
  } else {
    // 🔕 Silent reminder
    await notifications.show(
      id,
      params['title'] ?? 'Prayer Reminder',
      params['body'] ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Prayer Reminders',
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
        ),
      ),
    );
  }
}

class NotificationService {
  static const _key = 'prayer_settings';

  static Map<String, Map<String, dynamic>> prayerSettings = {
    'fajr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'dhuhr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'asr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'maghrib': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'isha': {'reminder': true, 'azan': true, 'minutesBefore': 10},
  };

  static Future<void> init() async {
    await AndroidAlarmManager.initialize();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: androidInit),
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // 🔔 AZAN CHANNEL (SYSTEM SOUND)
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'azan_channel',
        'Azan Notifications',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('azan'),
      ),
    );

    // 🔕 REMINDER CHANNEL
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminder_channel',
        'Prayer Reminders',
        importance: Importance.high,
        playSound: false,
      ),
    );
  }

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    prayerSettings = decoded.map(
      (k, v) => MapEntry(k, Map<String, dynamic>.from(v)),
    );
  }

  static Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(prayerSettings));
  }

  static Future<void> cancelPrayerAlarms() async {
    for (final base in [1000, 2000, 3000, 4000, 5000]) {
      await AndroidAlarmManager.cancel(base + 1); // azan
      await AndroidAlarmManager.cancel(base + 2); // reminder
    }
  }

  static Future<void> scheduleReminder({
    required int id,
    required DateTime time,
    required String prayer,
    required int minutes,
  }) async {
    await AndroidAlarmManager.oneShotAt(
      time,
      id,
      alarmCallback,
      exact: true,
      wakeup: true,
      params: {
        'title': 'Prayer Reminder',
        'body': '${prayer.toUpperCase()} in $minutes minutes',
        'playAzan': false,
      },
    );
  }

  static Future<void> scheduleAzan({
    required int id,
    required DateTime time,
    required String prayer,
  }) async {
    await AndroidAlarmManager.oneShotAt(
      time,
      id,
      alarmCallback,
      exact: true,
      wakeup: true,
      alarmClock: true,
      params: {
        'title': 'Time for ${prayer.toUpperCase()}',
        'body': 'Salah is better than sleep',
        'playAzan': true,
      },
    );
  }

  static Future<void> scheduleDailyRescheduler() async {
    final now = DateTime.now();
    final midnight = DateTime(
      now.year,
      now.month,
      now.day,
      0,
      5,
    ).add(const Duration(days: 1));

    await AndroidAlarmManager.oneShotAt(
      midnight,
      9999,
      dailyRescheduleCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }
}
