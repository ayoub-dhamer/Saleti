import 'dart:convert';
import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:saleti/utils/special_day_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'daily_rescheduler.dart';
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

  // ADDED (bug #6): dedicated id for the "Test azan" button on the
  // readiness banner, well outside every prayer's 1000-wide id block
  // (see alarmId below) and the other special ids above.
  static const int testAzanAlarmId = 6001;

  // FIXED (bug #3 — Doze safety): the daily 00:05 job was the *only* thing
  // that ever armed a day's native azan alarms, and that job is a Dart
  // callback scheduled with `exact: true` but no `allowWhileIdle` — a
  // plain `setExact()`, which Android defers to the next Doze maintenance
  // window. If that one run happened to land late (or android_alarm_manager_plus's
  // JobIntentService hop delayed it further — a known issue in Doze),
  // the whole day's prayers, Fajr included, would silently have nothing
  // scheduled. Native azan alarms are now pre-armed this many days ahead
  // whenever `rescheduleAllForToday` runs, so a single missed/late daily
  // job is just a missed top-up, not a missed prayer.
  static const int azanLookaheadDays = 7;

  static int alarmId(String prayer, String type, {int dayOffset = 0}) {
    // dayOffset*10 keeps each day's azan/reminder ids inside this prayer's
    // own 1000-wide block (bases are 1000 apart) for up to ~99 days of
    // lookahead — comfortably more than azanLookaheadDays ever needs.
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
      // FIXED: this used to also call AndroidAlarmManager.cancel() for the
      // azan id, but native azan alarms are armed directly against the
      // platform AlarmManager by AzanPlatformPlugin/AzanService — a
      // completely different PendingIntent than the one
      // android_alarm_manager_plus manages — so that call was cancelling
      // nothing. It happened to be harmless before because re-scheduling
      // the same id just replaced the old alarm, but it meant a prayer
      // whose azan had since been turned *off* could stay armed. cancelAzan()
      // below goes through the real 'azan_service' channel, and now covers
      // every pre-armed lookahead day, not just today.
      for (int dayOffset = 0; dayOffset < azanLookaheadDays; dayOffset++) {
        await cancelAzan(alarmId(prayer, 'azan', dayOffset: dayOffset));
      }
    }
  }

  /// Safety net for the gap left by scheduling Azan via raw native AlarmManager
  /// (bypassing android_alarm_manager_plus's own reboot-rescheduling). A plain
  /// reboot wipes all AlarmManager entries; only alarms registered *through*
  /// this plugin with rescheduleOnReboot get automatically re-armed after boot.
  /// This periodic alarm rides that mechanism to re-run rescheduleAllForToday
  /// so a mid-day reboot recovers. CHANGED: was every hour (24 headless-engine
  /// boots/day). Now that azan alarms are pre-armed several days ahead, a
  /// reboot no longer risks the rest of the *day's* prayers even if this
  /// catch-up itself only runs every few hours, so the interval was widened
  /// to reduce how often this wakes the device.
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
    // FIXED (bug #3): every caller below now passes true. Without it, this
    // was a plain setExact() under the hood, which Android defers to the
    // next Doze maintenance window instead of firing on time.
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

      // CHANGED (bug #3): used to schedule (or skip) only today's azan.
      // This now re-syncs today's azan *and* re-arms/cancels it across
      // the next `azanLookaheadDays` days too — see _syncAzanLookahead.
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

    // CHANGED: dropped onDidReceiveNotificationResponse /
    // onDidReceiveBackgroundNotificationResponse — those only existed to
    // handle the old Friday "Done" action button, which is now a native
    // PendingIntent on FridayReminderService's own notification and never
    // routes back through flutter_local_notifications at all.
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
    try {
      await platform.invokeMethod('stopFridayReminder');
    } catch (e) {
      debugPrint('Failed to stop Friday reminder: $e');
    }
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

  /// ADDED (bug #6): backs the "Test azan" button on the readiness banner.
  /// Arms the real native azan alarm a few seconds out under its own
  /// dedicated id, so the user hears exactly what a real prayer would
  /// sound like — same permissions, same scheduling path, same audio —
  /// instead of just being told a permission is "granted" and having to
  /// take that on faith until the next actual prayer.
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

  /// Arms or cancels a single prayer's azan for one specific calendar day
  /// (`dayOffset` days from today), based on the current `prayerSettings`.
  /// `time` should already be that day's occurrence of this prayer, or null
  /// if it couldn't be computed (e.g. no cached location yet) — either a
  /// null time or a disabled/past-due setting cancels that slot instead.
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

  /// Re-syncs one prayer's azan across today (using the already-computed
  /// `todaysTime`) and the next `azanLookaheadDays` days (computed fresh
  /// from the cached location). Used both by `rescheduleAllForToday` for
  /// every prayer, and directly from the UI when a single prayer's azan
  /// toggle or volume changes, so that change is reflected on every
  /// pre-armed day, not just today.
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
        final futureDate = DateTime.now().add(Duration(days: dayOffset));
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

  /// Public entry point for the UI: call this after changing one prayer's
  /// azan on/off or volume so today's alarm *and* the pre-armed lookahead
  /// days both reflect the change immediately, instead of only today being
  /// updated and the other ~30 already-armed alarms staying on the old
  /// setting until the next full reschedule.
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

  // FIXED (bug #10): starting the foreground service used to run *before*
  // rescheduling next Friday. Starting a foreground service from this
  // background callback can throw (Android 12+'s background-start
  // restrictions among other reasons) — when it did, the two
  // scheduleFridayReminder*/End calls below never ran, so no future
  // Friday ever got scheduled again: one failed run permanently ended
  // the weekly reminder. Rescheduling first means next Friday is always
  // armed regardless of whether *this* Friday's notification managed to
  // show, and the start is now wrapped so a failure here can't take the
  // schedule down with it.
  await NotificationService.scheduleFridayReminder();
  await NotificationService.scheduleFridayReminderEnd();

  const platform = MethodChannel('azan_service');
  try {
    await platform.invokeMethod('startFridayReminder');
  } catch (e) {
    debugPrint('Failed to start Friday reminder: $e');
  }
}

@pragma('vm:entry-point')
Future<void> fridayReminderEndCallback() async {
  WidgetsFlutterBinding.ensureInitialized();

  const platform = MethodChannel('azan_service');
  try {
    await platform.invokeMethod('stopFridayReminder');
  } catch (e) {
    debugPrint('Failed to stop Friday reminder: $e');
  }
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
        'friday_reminder_channel',
        'Friday Reminder',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
      ),
    ),
  );
}
