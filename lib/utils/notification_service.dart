import 'dart:convert';
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:saleti/utils/special_day_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_rescheduler.dart';
import 'date_helpers.dart';
import 'prayer_cache.dart';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> alarmCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidInit = AndroidInitializationSettings(
    '@drawable/ic_notification',
  ); // CHANGED: was '@mipmap/ic_launcher'
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

  static const int fridayReminderAlarmId = 8001;
  static const int fridayReminderEndAlarmId = 8002;
  static const int fridayReminderNotificationId = fridayReminderAlarmId;

  static const String _eidOffsetKey = 'eid_offset_minutes';
  static int eidOffsetMinutes = 20;

  static const int eidNotificationId = 7777;
  static const int eidAlarmId = 7001;

  static const int rebootCatchUpAlarmId = 9998;

  static const int testAzanAlarmId = 6001;

  static const int azanLookaheadDays = 7;

  static int alarmId(String prayer, String type, {int dayOffset = 0}) {
    return _prayerAlarmBase[prayer]! +
        (type == 'azan' ? 1 : 2) +
        dayOffset * 10;
  }

  static Prayer _prayerEnum(String key) {
    switch (key) {
      case 'fajr':
        return Prayer.fajr;
      case 'dhuhr':
        return Prayer.dhuhr;
      case 'asr':
        return Prayer.asr;
      case 'maghrib':
        return Prayer.maghrib;
      case 'isha':
        return Prayer.isha;
      default:
        throw ArgumentError('Unknown prayer key: $key');
    }
  }

  static Future<void> cancelPrayerAlarms() async {
    for (final prayer in _prayerAlarmBase.keys) {
      await AndroidAlarmManager.cancel(alarmId(prayer, 'reminder'));

      for (int dayOffset = 0; dayOffset < azanLookaheadDays; dayOffset++) {
        await cancelAzan(alarmId(prayer, 'azan', dayOffset: dayOffset));
      }
    }
  }

  static Future<void> scheduleRebootCatchUp() async {
    try {
      await AndroidAlarmManager.periodic(
        const Duration(hours: 4),
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
    bool allowWhileIdle = true,
  }) async {
    try {
      await AndroidAlarmManager.oneShotAt(
        time,
        id,
        callback,
        exact: true,
        wakeup: true,
        allowWhileIdle: allowWhileIdle,
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

      if (setting['reminder'] == true) {
        final minutes = (setting['minutesBefore'] as num?)?.toInt() ?? 10;
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

      await _syncAzanLookahead(prayer, time);
    }

    await scheduleEidReminderIfApplicable(todaysPrayerTimes: prayerTimes);
    await scheduleDailyRescheduler();
  }

  // ----------------------------------------------------------
  // INIT
  // ----------------------------------------------------------

  static Future<void> init() async {
    await AndroidAlarmManager.initialize();

    const androidInit = AndroidInitializationSettings(
      '@drawable/ic_notification',
    ); // CHANGED: was '@mipmap/ic_launcher'
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

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'friday_reminder_channel',
        'Friday Reminder',
        description: "Weekly reminder to prepare for Salat al-Jumu'ah",
        importance: Importance.max,
        playSound: true,
      ),
    );

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'eid_channel',
        'Eid Reminder',
        description: 'Reminder for Eid al-Fitr and Eid al-Adha prayer',
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

    DateTime nextFriday = addDays(
      DateTime(now.year, now.month, now.day, hour, minute),
      daysUntilFriday,
    );

    if (daysUntilFriday == 0 && nextFriday.isBefore(now)) {
      nextFriday = addDays(nextFriday, 7);
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

    final endOfDay = addDays(DateTime(now.year, now.month, now.day), 1);

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
    // FIXED (bug #10, part 3): no more MethodChannel call to a native
    // service — just cancel the plain notification directly.
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
  // REMINDER (DART)
  // ----------------------------------------------------------

  static Future<void> scheduleReminder({
    required int id,
    required DateTime time,
    required String prayer,
    required int minutes,
  }) async {
    final displayName = SpecialDayHelper.prettyPrayerName(prayer, time);

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

  static Future<void> testAzan() async {
    await scheduleAzanNative(
      id: testAzanAlarmId,
      time: DateTime.now().add(const Duration(seconds: 5)),
      prayer: 'Test',
      volume: 1.0,
      azanEnabled: true,
    );
  }

  static Future<void> cancelAzan(int id) async {
    const platform = MethodChannel('azan_service');
    try {
      await platform.invokeMethod('cancelAzanNative', {'id': id});
    } catch (e) {
      debugPrint('Failed to cancel Azan: $e');
    }
  }

  static Future<void> _applyAzanForPrayerOnDay({
    required String prayer,
    required int dayOffset,
    required DateTime? time,
  }) async {
    final id = alarmId(prayer, 'azan', dayOffset: dayOffset);
    final setting = prayerSettings[prayer]!;
    final enabled = setting['azan'] == true;
    final volume = (setting['volume'] is double)
        ? setting['volume'] as double
        : 1.0;

    if (!enabled || time == null || !time.isAfter(DateTime.now())) {
      await cancelAzan(id);
      return;
    }

    await scheduleAzanNative(
      id: id,
      time: time,
      prayer: prayer,
      volume: volume,
      azanEnabled: true,
    );
  }

  static Future<void> _syncAzanLookahead(
    String prayer,
    DateTime todaysTime,
  ) async {
    await _applyAzanForPrayerOnDay(
      prayer: prayer,
      dayOffset: 0,
      time: todaysTime,
    );

    final cache = PrayerCache();
    for (int dayOffset = 1; dayOffset < azanLookaheadDays; dayOffset++) {
      DateTime? time;
      if (cache.hasLocation) {
        final futureDate = addDays(DateTime.now(), dayOffset);
        time = cache
            .calculatePrayerTimesFor(futureDate)
            .timeForPrayer(_prayerEnum(prayer));
      }
      await _applyAzanForPrayerOnDay(
        prayer: prayer,
        dayOffset: dayOffset,
        time: time,
      );
    }
  }

  static Future<void> applyAzanSettingForPrayer(
    String prayer,
    DateTime todaysTime,
  ) async {
    await _syncAzanLookahead(prayer, todaysTime);
  }

  // ----------------------------------------------------------
  // DAILY RESCHEDULER
  // ----------------------------------------------------------

  static Future<void> scheduleDailyRescheduler() async {
    final now = DateTime.now();

    final midnight = addDays(DateTime(now.year, now.month, now.day, 0, 5), 1);

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

  await NotificationService.scheduleFridayReminder();
  await NotificationService.scheduleFridayReminderEnd();

  const androidInit = AndroidInitializationSettings(
    '@drawable/ic_notification',
  );
  final notifications = FlutterLocalNotificationsPlugin();

  try {
    await notifications.initialize(
      const InitializationSettings(android: androidInit),
    );

    await notifications.show(
      NotificationService.fridayReminderNotificationId,
      "It's Jumu'ah Day",
      "Today is Friday — shower and read Surah Al-Kahf to get ready for Salat al-Jumu'ah.",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'friday_reminder_channel',
          'Friday Reminder',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          // Best-effort only, not enforced the way a foreground service's
          // notification could be — the user (or the OS) can still swipe
          // this away, same as any other Android 14+ ongoing notification.
          ongoing: false,
          autoCancel: true,
        ),
      ),
    );
  } catch (e) {
    debugPrint('Failed to show Friday reminder: $e');
  }
}

@pragma('vm:entry-point')
Future<void> fridayReminderEndCallback() async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidInit = AndroidInitializationSettings(
    '@drawable/ic_notification',
  );
  final notifications = FlutterLocalNotificationsPlugin();

  try {
    await notifications.initialize(
      const InitializationSettings(android: androidInit),
    );
    await notifications.cancel(
      NotificationService.fridayReminderNotificationId,
    );
  } catch (e) {
    debugPrint('Failed to clear Friday reminder: $e');
  }
}

@pragma('vm:entry-point')
Future<void> eidReminderCallback(int id, Map<String, dynamic> params) async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidInit = AndroidInitializationSettings(
    '@drawable/ic_notification',
  ); // CHANGED: was '@mipmap/ic_launcher'

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
        'eid_channel',
        'Eid Reminder',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
    ),
  );
}
