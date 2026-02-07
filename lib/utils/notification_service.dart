import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:saleti/utils/daily_rescheduler.dart';
import 'package:saleti/utils/foreground_azan_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

/// ⚠️ Must be top-level for Android Alarm Manager
@pragma('vm:entry-point')
Future<void> alarmCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);

  final notifications = FlutterLocalNotificationsPlugin();
  await notifications.initialize(settings);

  // 🔕 Silent notification
  await notifications.show(
    id,
    params['title'],
    params['body'],
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'azan_channel',
        'Prayer',
        importance: Importance.max,
        priority: Priority.high,
        playSound: false,
      ),
    ),
  );

  // 🔊 START foreground service (NOT sendData)
  if (params['playAzan'] == true) {
    await FlutterForegroundTask.startService(
      notificationTitle: 'Prayer Time',
      notificationText: 'Azan is playing',
      callback: startAzanCallback,
    );
  }
}

@pragma('vm:entry-point')
void startAzanCallback() {
  FlutterForegroundTask.setTaskHandler(PrayerTaskHandler());
}

class NotificationService {
  static const _key = 'prayer_settings';

  // Default prayer notification settings
  static Map<String, Map<String, dynamic>> prayerSettings = {
    'fajr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'dhuhr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'asr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'maghrib': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'isha': {'reminder': true, 'azan': true, 'minutesBefore': 10},
  };

  /// Initialize notifications and alarm manager
  static Future<void> init() async {
    // Initialize Android Alarm Manager
    await AndroidAlarmManager.initialize();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notifications.initialize(settings);

    // Create channels for Android
    const azanChannel = AndroidNotificationChannel(
      'azan_channel',
      'Azan Notifications',
      description: 'Plays azan sound at prayer time',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('azan'),
    );

    const reminderChannel = AndroidNotificationChannel(
      'reminder_channel',
      'Prayer Reminders',
      description: 'Silent prayer reminders',
      importance: Importance.high,
      playSound: false,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(azanChannel);
    await androidPlugin?.createNotificationChannel(reminderChannel);
  }

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    if (raw == null) return;

    final decoded = jsonDecode(raw) as Map<String, dynamic>;

    prayerSettings = decoded.map(
      (prayer, settings) =>
          MapEntry(prayer, Map<String, dynamic>.from(settings)),
    );
  }

  /// 🔹 SAVE SETTINGS
  static Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(prayerSettings);
    await prefs.setString(_key, jsonString);
  }

  /// Schedule a reminder notification (silent)
  static Future<void> scheduleReminder({
    required int id,
    required DateTime time,
    required String prayer,
    required int minutes,
  }) async {
    if (time.isBefore(DateTime.now())) return;

    await AndroidAlarmManager.oneShotAt(
      time,
      id,
      alarmCallback,
      exact: true,
      wakeup: true,
      params: {
        'title': 'Prayer Reminder',
        'body': '$prayer in $minutes minutes',
        'channel': 'reminder_channel',
        'playSound': false,
      },
    );
  }

  /// Schedule Azan notification with sound
  static Future<void> scheduleAzan({
    required int id,
    required DateTime time,
    required String prayer,
  }) async {
    if (time.isBefore(DateTime.now())) return;

    await AndroidAlarmManager.oneShotAt(
      time,
      id,
      alarmCallback,
      exact: true,
      wakeup: true,
      params: {
        'title': 'Time for Prayer',
        'body': 'It is time for $prayer prayer',
        'playAzan': true, // 👈 triggers foreground audio
      },
    );
  }

  /// Cancel all scheduled alarms (for rescheduling)
  static Future<void> cancelAll() async {
    for (int i = 0; i < 5000; i++) {
      await AndroidAlarmManager.cancel(i);
    }
  }

  static Future<void> scheduleDailyRescheduler() async {
    final now = DateTime.now();

    final midnight = DateTime(
      now.year,
      now.month,
      now.day,
      0,
      5, // 00:05 AM
    ).add(const Duration(days: 1));

    await AndroidAlarmManager.oneShotAt(
      midnight,
      9999, // reserved ID
      dailyRescheduleCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }
}
