import 'package:flutter/widgets.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'notification_service.dart';
import 'prayer_cache.dart';

@pragma('vm:entry-point')
Future<void> dailyRescheduleCallback() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cache = PrayerCache();
  await cache.load();

  if (!cache.hasLocation) return;

  final prayerTimes = cache.calculatePrayerTimes();

  await NotificationService.cancelAll();

  final map = {
    'fajr': prayerTimes.fajr,
    'dhuhr': prayerTimes.dhuhr,
    'asr': prayerTimes.asr,
    'maghrib': prayerTimes.maghrib,
    'isha': prayerTimes.isha,
  };

  int id = 100;

  for (final entry in map.entries) {
    final prayer = entry.key;
    final time = entry.value;
    final setting = NotificationService.prayerSettings[prayer]!;

    if (setting['reminder'] == true) {
      final minutes = setting['minutesBefore'] as int;
      final reminderTime = time.subtract(Duration(minutes: minutes));

      await NotificationService.scheduleReminder(
        id: id++,
        time: reminderTime,
        prayer: prayer,
        minutes: minutes,
      );
    }

    if (setting['azan'] == true) {
      await NotificationService.scheduleAzan(
        id: id++,
        time: time,
        prayer: prayer,
      );
    }
  }
  await NotificationService.scheduleDailyRescheduler();
}
