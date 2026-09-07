import 'dart:convert';
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:saleti/utils/special_day_helper.dart';
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

  static const Map<String, int> _prayerAlarmBase = {
    'fajr': 1000,
    'dhuhr': 2000,
    'asr': 3000,
    'maghrib': 4000,
    'isha': 5000,
  };

  // CHANGED: fridayReminderNotificationId removed — the Friday reminder is
  // now a native foreground-service notification (see FridayReminderService.kt),
  // no longer posted or cancelled via flutter_local_notifications, so this
  // ID has no remaining use.
  static const int fridayReminderAlarmId = 8001;
  static const int fridayReminderEndAlarmId = 8002;

  static const String _eidOffsetKey = 'eid_offset_minutes';
  static int eidOffsetMinutes = 20;

  static const int eidNotificationId = 7777;
  static const int eidAlarmId = 7001;

  static const int rebootCatchUpAlarmId = 9998;

  static int alarmId(String prayer, String type) {
    return _prayerAlarmBase[prayer]! + (type == 'azan' ? 1 : 2);
  }

  static Future<void> cancelPrayerAlarms() async {
    for (final base in _prayerAlarmBase.values) {
      await AndroidAlarmManager.cancel(base + 1); // azan
      await AndroidAlarmManager.cancel(base + 2); // reminder
    }
  }

  /// Safety net for the gap left by scheduling Azan via raw native AlarmManager
  /// (bypassing android_alarm_manager_plus's own reboot-rescheduling). A plain
  /// reboot wipes all AlarmManager entries; only alarms registered *through*
  /// this plugin with rescheduleOnReboot get automatically re-armed after boot.
  /// This periodic alarm rides that mechanism to re-run rescheduleAllForToday
  /// roughly hourly, so a mid-day reboot recovers within ~1hr instead of
  /// silently missing the rest of the day's prayers until midnight or the
  /// user reopening the app.
  static Future<void> scheduleRebootCatchUp() async {
    try {
      await AndroidAlarmManager.periodic(
        const Duration(hours: 1),
        rebootCatchUpAlarmId,
        dailyRescheduleCallback,
        exact: false,
        wakeup: true,
        rescheduleOnReboot: true,
      );
    } catch (e) {
      debugPrint('Failed to schedule reboot catch-up alarm: $e');
    }
  }

  static Future<void> _safeOneShot(
    DateTime time,
    int id,
    Function callback, {
    Map<String, dynamic>? params,
    bool rescheduleOnReboot = false,
  }) async {
    try {
      await AndroidAlarmManager.oneShotAt(
        time,
        id,
        callback,
        exact: true,
        wakeup: true,
        params: params ?? {},
        rescheduleOnReboot: rescheduleOnReboot,
      );
    } catch (e) {
      debugPrint('Failed to schedule alarm $id at $time: $e');
    }
  }

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

  static Future<void> scheduleEidReminderIfApplicable({
    required PrayerTimes? todaysPrayerTimes,
  }) async {
    final eidName = SpecialDayHelper.eidNameFor(DateTime.now());
    if (eidName == null || todaysPrayerTimes == null) {
      return;
    }

    final estimatedTime = SpecialDayHelper.estimatedEidTime(
      todaysPrayerTimes,
      offsetMinutes: eidOffsetMinutes,
    );

    if (estimatedTime.isBefore(DateTime.now())) return;

    await _safeOneShot(
      estimatedTime,
      eidAlarmId,
      eidReminderCallback,
      params: {'eidName': eidName},
    );
  }

  static Future<void> cancelEidReminder() async {
    await AndroidAlarmManager.cancel(eidAlarmId);
    await _notifications.cancel(eidNotificationId);
  }

  /// Single source of truth for "cancel + reschedule everything for today".
  static Future<void> rescheduleAllForToday(PrayerTimes prayerTimes) async {
    final map = {
      'fajr': prayerTimes.fajr,
      'dhuhr': prayerTimes.dhuhr,
      'asr': prayerTimes.asr,
      'maghrib': prayerTimes.maghrib,
      'isha': prayerTimes.isha,
    };

    for (final entry in map.entries) {
      final prayer = entry.key;
      final time = entry.value;
      final setting = prayerSettings[prayer]!;

      await AndroidAlarmManager.cancel(alarmId(prayer, 'reminder'));
      await AndroidAlarmManager.cancel(alarmId(prayer, 'azan'));

      if (setting['reminder'] == true) {
        final minutes = setting['minutesBefore'] as int;
        final reminderTime = time.subtract(Duration(minutes: minutes));
        if (reminderTime.isAfter(DateTime.now())) {
          await scheduleReminder(
            id: alarmId(prayer, 'reminder'),
            time: reminderTime,
            prayer: prayer,
            minutes: minutes,
          );
        }
      }

      if (setting['azan'] == true && time.isAfter(DateTime.now())) {
        await scheduleAzanNative(
          id: alarmId(prayer, 'azan'),
          time: time,
          prayer: prayer,
          volume: (setting['volume'] is double) ? setting['volume'] : 1.0,
          azanEnabled: true,
        );
      }
    }

    await scheduleEidReminderIfApplicable(todaysPrayerTimes: prayerTimes);
    await scheduleDailyRescheduler();
  }

  // ----------------------------------------------------------
  // INIT
  // ----------------------------------------------------------

  static Future<void> init() async {
    await AndroidAlarmManager.initialize();

    // CHANGED: dropped onDidReceiveNotificationResponse /
    // onDidReceiveBackgroundNotificationResponse — those only existed to
    // handle the old Friday "Done" action button, which is now a native
    // PendingIntent on FridayReminderService's own notification and never
    // routes back through flutter_local_notifications at all.
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

    // KEPT: still needed here, even though the Friday reminder notification
    // itself moved to FridayReminderService.kt — eidReminderCallback below
    // posts to this same channel ID via flutter_local_notifications, and
    // that channel must exist before the first Eid ever fires, not just
    // after the first Friday reminder happens to run.
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
  // FRIDAY REMINDER
  // ----------------------------------------------------------

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

    if (daysUntilFriday == 0 && nextFriday.isBefore(now)) {
      nextFriday = nextFriday.add(const Duration(days: 7));
    }

    await _safeOneShot(
      nextFriday,
      fridayReminderAlarmId,
      fridayReminderCallback,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> scheduleFridayReminderEnd() async {
    final now = DateTime.now();
    final endOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    await _safeOneShot(
      endOfDay,
      fridayReminderEndAlarmId,
      fridayReminderEndCallback,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> cancelFridayReminder() async {
    await AndroidAlarmManager.cancel(fridayReminderAlarmId);
    await AndroidAlarmManager.cancel(fridayReminderEndAlarmId);

    const platform = MethodChannel('azan_service');
    await platform.invokeMethod('stopFridayReminder');
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
  // REMINDER (DART)
  // ----------------------------------------------------------

  static Future<void> scheduleReminder({
    required int id,
    required DateTime time,
    required String prayer,
    required int minutes,
  }) async {
    final displayName = SpecialDayHelper.prettyPrayerName(prayer, time);

    // CHANGED: dropped the unused 'playAzan' param — alarmCallback no
    // longer branches on it (that dead branch was removed earlier), so
    // passing it here served no purpose.
    await _safeOneShot(
      time,
      id,
      alarmCallback,
      params: {
        'title': 'Prayer Reminder',
        'body': '$displayName in $minutes minutes',
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
    required bool azanEnabled,
  }) async {
    try {
      await _platform.invokeMethod('scheduleAzanNative', {
        'id': id,
        'timestamp': time.millisecondsSinceEpoch,
        'prayer': prayer,
        'volume': volume,
        'azanEnabled': azanEnabled,
      });
    } catch (e) {
      debugPrint('Failed to schedule native Azan: $e');
    }
  }

  static Future<void> stopAzan() async {
    try {
      await _platform.invokeMethod('stopAzan');
    } catch (e) {
      debugPrint('Failed to stop Azan: $e');
    }
  }

  static Future<void> cancelAzan(int id) async {
    const platform = MethodChannel('azan_service');
    try {
      await platform.invokeMethod('cancelAzanNative', {'id': id});
    } catch (e) {
      debugPrint('Failed to cancel Azan: $e');
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

    await _safeOneShot(
      midnight,
      9999,
      dailyRescheduleCallback,
      rescheduleOnReboot: true,
    );
  }
}

// ----------------------------------------------------------
// TOP-LEVEL CALLBACKS
// ----------------------------------------------------------

@pragma('vm:entry-point')
Future<void> fridayReminderCallback() async {
  WidgetsFlutterBinding.ensureInitialized();

  const platform = MethodChannel('azan_service');
  await platform.invokeMethod('startFridayReminder');

  await NotificationService.scheduleFridayReminder();
  await NotificationService.scheduleFridayReminderEnd();
}

@pragma('vm:entry-point')
Future<void> fridayReminderEndCallback() async {
  WidgetsFlutterBinding.ensureInitialized();

  const platform = MethodChannel('azan_service');
  await platform.invokeMethod('stopFridayReminder');
}

// REMOVED: _handleFridayNotificationResponse and notificationTapBackground.
// Both only existed to react to a tap on the old flutter_local_notifications
// "Done" action, which no longer exists — the Done button is now a native
// PendingIntent wired directly to FridayReminderService's ACTION_STOP, so
// nothing on the Dart side ever needs to observe a notification response
// for this anymore.

@pragma('vm:entry-point')
Future<void> eidReminderCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  final notifications = FlutterLocalNotificationsPlugin();

  await notifications.initialize(
    const InitializationSettings(android: androidInit),
  );

  final eidName = params['eidName'] as String? ?? 'Eid';

  await notifications.show(
    NotificationService.eidNotificationId,
    '$eidName Mubarak!',
    "It's time for Eid prayer — estimated based on today's sunrise. Confirm the exact time with your local mosque.",
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'friday_reminder_channel',
        'Friday Reminder',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
    ),
  );
}
