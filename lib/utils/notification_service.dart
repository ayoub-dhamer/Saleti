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

  static const int fridayReminderNotificationId = 8888;
  static const int fridayReminderAlarmId = 8001;
  static const int fridayReminderEndAlarmId = 8002;

  static const String _eidOffsetKey = 'eid_offset_minutes';
  static int eidOffsetMinutes = 20;

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
      onDidReceiveNotificationResponse:
          _handleFridayNotificationResponse, // ADD
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
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

    // ADD: Friday reminder channel
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'friday_reminder_channel',
        'Friday Reminder',
        description: "Weekly reminder to prepare for Salat al-Jumu'ah",
        importance: Importance.max,
        playSound: true,
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
  // FRIDAY REMINDER (ADD — new section)
  // ----------------------------------------------------------

  /// Schedules the next Friday reminder at the given local time.
  /// Safe to call repeatedly (e.g. on every app start) — it just
  /// recomputes and overwrites the same alarm ID.
  static Future<void> scheduleFridayReminder({
    int hour = 8,
    int minute = 0,
  }) async {
    final now = DateTime.now();
    int daysUntilFriday = (DateTime.friday - now.weekday + 7) % 7;

    DateTime nextFriday = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).add(Duration(days: daysUntilFriday));

    // If today IS Friday but the time already passed, roll to next week
    if (daysUntilFriday == 0 && nextFriday.isBefore(now)) {
      nextFriday = nextFriday.add(const Duration(days: 7));
    }
    await AndroidAlarmManager.oneShotAt(
      nextFriday,
      fridayReminderAlarmId,
      fridayReminderCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  /// Schedules a cleanup alarm for the end of the current day (midnight),
  /// which force-dismisses the reminder if the user never tapped "Done".
  static Future<void> scheduleFridayReminderEnd() async {
    final now = DateTime.now();
    final endOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    await AndroidAlarmManager.oneShotAt(
      endOfDay,
      fridayReminderEndAlarmId,
      fridayReminderEndCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> cancelFridayReminder() async {
    await AndroidAlarmManager.cancel(fridayReminderAlarmId);
    await AndroidAlarmManager.cancel(fridayReminderEndAlarmId);
    await _notifications.cancel(fridayReminderNotificationId);
  }

  static Future<void> loadEidOffset() async {
    final prefs = await SharedPreferences.getInstance();
    eidOffsetMinutes = prefs.getInt(_eidOffsetKey) ?? 20;
  }

  static Future<void> saveEidOffset(int minutes) async {
    eidOffsetMinutes = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_eidOffsetKey, minutes);
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

// ----------------------------------------------------------
// TOP-LEVEL CALLBACKS (required by android_alarm_manager_plus
// and flutter_local_notifications background dispatch)
// ----------------------------------------------------------

@pragma('vm:entry-point')
Future<void> fridayReminderCallback() async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final notifications = FlutterLocalNotificationsPlugin();

  await notifications.initialize(
    const InitializationSettings(android: androidInit),
    onDidReceiveNotificationResponse: _handleFridayNotificationResponse,
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
  );
  const androidDetails = AndroidNotificationDetails(
    'friday_reminder_channel',
    'Friday Reminder',
    channelDescription: "Weekly reminder to prepare for Salat al-Jumu'ah",
    importance: Importance.max,
    priority: Priority.high,
    ongoing: true, // prevents swipe-to-dismiss
    autoCancel: false, // tapping the body won't dismiss it either
    playSound: true,
    actions: [
      AndroidNotificationAction(
        'friday_done',
        'Done',
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ],
  );
  await notifications.show(
    NotificationService.fridayReminderNotificationId,
    "It's Jumu'ah Day",
    "Today is Friday — shower and read Surah Al-Kahf to get ready for Salat al-Jumu'ah.",
    const NotificationDetails(android: androidDetails),
  );

  // Reschedule for next week, and arm the end-of-day cleanup
  await NotificationService.scheduleFridayReminder();
  await NotificationService.scheduleFridayReminderEnd();
}

@pragma('vm:entry-point')
Future<void> fridayReminderEndCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final notifications = FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    const InitializationSettings(android: androidInit),
  );
  await notifications.cancel(NotificationService.fridayReminderNotificationId);
}

/// Handles the "Done" action tap while the app is alive (foreground/background).
@pragma('vm:entry-point')
void _handleFridayNotificationResponse(NotificationResponse response) async {
  if (response.actionId == 'friday_done') {
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.cancel(
      NotificationService.fridayReminderNotificationId,
    );
  }
}

/// Handles the "Done" action tap when the app process is terminated.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  _handleFridayNotificationResponse(response);
}
