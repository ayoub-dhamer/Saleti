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

@pragma('vm:entry-point')
Future<void> alarmCallback(int id, Map<String, dynamic> params) async {
  // 1. Critical for closed-app execution
  WidgetsFlutterBinding.ensureInitialized();

  final bool isAzan = params['playAzan'] == true;

  if (isAzan) {
    // 2. Check if already running to prevent overlap
    if (await FlutterForegroundTask.isRunningService) return;

    // 3. Start the foreground service which handles the audio
    await FlutterForegroundTask.startService(
      notificationTitle: params['title'] ?? "Prayer Time",
      notificationText: params['body'] ?? "Azan is playing...",
      callback: startAzanCallback,
    );
  } else {
    // Standard reminder logic
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      const InitializationSettings(android: android),
    );

    await notifications.show(
      id,
      params['title'],
      params['body'],
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminders',
          importance: Importance.high,
          priority: Priority.high,
          playSound: false,
        ),
      ),
    );
  }
}

@pragma('vm:entry-point')
void startAzanCallback() {
  FlutterForegroundTask.setTaskHandler(PrayerTaskHandler());
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

    // 🆕 Initialize Foreground Task Options for Android 15
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'azan_channel',
        channelName: 'Azan Notifications',
        channelImportance: NotificationChannelImportance.MAX,
        priority: NotificationPriority.MAX,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifications.initialize(
      const InitializationSettings(android: android),
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'azan_channel',
        'Azan Notifications',
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('azan'),
      ),
    );

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
      rescheduleOnReboot: true,
      params: {
        'title': 'Prayer Reminder',
        'body':
            '${prayer[0].toUpperCase() + prayer.substring(1)} in $minutes minutes',
        'playAzan': false,
      },
    );
  }

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
      alarmClock: true, // 🚨 Critical: Wakes up phone from deep sleep
      allowWhileIdle: true,
      rescheduleOnReboot: true,
      params: {
        'title': 'Time for ${prayer[0].toUpperCase() + prayer.substring(1)}',
        'body': 'Salah is better than sleep',
        'playAzan': true,
      },
    );
  }

  static Future<void> testAzanNow() async {
    await FlutterForegroundTask.startService(
      notificationTitle: 'Azan Testing',
      notificationText: 'Testing the prayer call audio...',
      callback: startAzanCallback,
    );
  }

  static Future<void> cancelAll() async {
    for (int i = 0; i < 10000; i++) {
      await AndroidAlarmManager.cancel(i);
    }
  }

  static Future<void> scheduleDailyRescheduler() async {
    final now = DateTime.now();

    // Calculate tomorrow at 00:05 AM
    final midnight = DateTime(
      now.year,
      now.month,
      now.day,
      0,
      5,
    ).add(const Duration(days: 1));

    await AndroidAlarmManager.oneShotAt(
      midnight,
      9999, // Reserved ID for the rescheduler
      dailyRescheduleCallback, // The function in daily_rescheduler.dart
      exact: true,
      wakeup: true,
      rescheduleOnReboot:
          true, // Crucial: sets it back up if the phone restarts
    );
  }
}
