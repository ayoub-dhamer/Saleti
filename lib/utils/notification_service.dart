import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_rescheduler.dart';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> alarmCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();

  final bool isAzan = params['playAzan'] == true;

  if (isAzan) {
    // ✅ START FOREGROUND SERVICE (PASS PRAYER NAME)
    const platform = MethodChannel('azan_service');
    final prayerName = params['prayer'] ?? 'Prayer';
    await platform.invokeMethod('startAzan', {'prayer': prayerName});
    return;
  }

  // 🔕 Silent reminder notification
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final notifications = FlutterLocalNotificationsPlugin();

  await notifications.initialize(
    const InitializationSettings(android: androidInit),
  );

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

class NotificationService {
  static const _key = 'prayer_settings';

  static Map<String, Map<String, dynamic>> prayerSettings = {
    'fajr': {
      'reminder': true,
      'azan': true,
      'minutesBefore': 10,
      'volume': 1.0,
    },
    'dhuhr': {
      'reminder': true,
      'azan': true,
      'minutesBefore': 10,
      'volume': 1.0,
    },
    'asr': {'reminder': true, 'azan': true, 'minutesBefore': 10, 'volume': 1.0},
    'maghrib': {
      'reminder': true,
      'azan': true,
      'minutesBefore': 10,
      'volume': 1.0,
    },
    'isha': {
      'reminder': true,
      'azan': true,
      'minutesBefore': 10,
      'volume': 1.0,
    },
  };

  static const MethodChannel _platform = MethodChannel('azan_service');

  // ----------------------------------------------------------
  // INIT
  // ----------------------------------------------------------

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

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminder_channel',
        'Prayer Reminders',
        importance: Importance.high,
        playSound: false,
      ),
    );
  }

  // ----------------------------------------------------------
  // SETTINGS
  // ----------------------------------------------------------

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

  // ----------------------------------------------------------
  // CANCEL
  // ----------------------------------------------------------

  static Future<void> cancelPrayerAlarms() async {
    for (final base in [1000, 2000, 3000, 4000, 5000]) {
      await AndroidAlarmManager.cancel(base + 1); // azan
      await AndroidAlarmManager.cancel(base + 2); // reminder
    }
  }

  // ----------------------------------------------------------
  // REMINDER (DART)
  // ----------------------------------------------------------

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
        'body': '$prayer in $minutes minutes',
        'playAzan': false,
      },
    );
  }

  // ----------------------------------------------------------
  // AZAN → NATIVE SCHEDULING
  // ----------------------------------------------------------

  static Future<void> scheduleAzanNative({
    required int id,
    required DateTime time,
    required String prayer,
    required double volume,
    required bool azanEnabled, // default true
  }) async {
    try {
      await _platform.invokeMethod('scheduleAzanNative', {
        'id': id,
        'timestamp': time.millisecondsSinceEpoch,
        'prayer': prayer,
        'volume': volume,
        'azanEnabled': azanEnabled, // pass to native
      });
    } on PlatformException catch (e) {
      debugPrint('Failed to schedule native Azan: ${e.message}');
    }
  }

  static Future<void> stopAzan() async {
    await _platform.invokeMethod('stopAzan');
  }

  static Future<void> testAzan(String prayer) async {
    await _platform.invokeMethod('startAzan', {'prayer': prayer});
  }

  static Future<void> stopTestAzan() async {
    await _platform.invokeMethod('stopAzan');
  }

  static Future<void> cancelAzan(int id) async {
    const platform = MethodChannel('azan_service');
    try {
      await platform.invokeMethod('cancelAzanNative', {'id': id});
    } on PlatformException catch (e) {
      debugPrint('Failed to cancel Azan: ${e.message}');
    }
  }

  // ----------------------------------------------------------
  // DAILY RESCHEDULER
  // ----------------------------------------------------------

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
