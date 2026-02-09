import 'package:flutter/widgets.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'notification_service.dart';
import 'prayer_cache.dart';

@pragma('vm:entry-point')
Future<void> dailyRescheduleCallback() async {
  // 1. Critical: Initialize the framework for background work
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Load the user's prayer settings (Isolate has its own memory!)
  // This ensures the background task knows if the user turned off Fajr Azan, etc.
  await NotificationService.loadSettings();

  final cache = PrayerCache();
  await cache.load();

  if (!cache.hasLocation) return;

  final prayerTimes = cache.calculatePrayerTimes();

  // 3. Clear old alarms to prevent "ghost" notifications
  await NotificationService.cancelAll();

  final map = {
    'fajr': prayerTimes.fajr,
    'dhuhr': prayerTimes.dhuhr,
    'asr': prayerTimes.asr,
    'maghrib': prayerTimes.maghrib,
    'isha': prayerTimes.isha,
  };

  // 4. Use consistent IDs matching your Screen logic
  // Consistent IDs are vital so that if the user opens the app,
  // they can override these alarms without creating duplicates.
  int _getAlarmId(String prayer, String type) {
    const base = {
      'fajr': 1000,
      'dhuhr': 2000,
      'asr': 3000,
      'maghrib': 4000,
      'isha': 5000,
    };
    return base[prayer]! + (type == 'azan' ? 1 : 2);
  }

  for (final entry in map.entries) {
    final prayer = entry.key;
    final time = entry.value;
    final setting = NotificationService.prayerSettings[prayer]!;

    // Only schedule if the time is in the future
    if (setting['reminder'] == true) {
      final minutes = setting['minutesBefore'] as int;
      final reminderTime = time.subtract(Duration(minutes: minutes));

      if (reminderTime.isAfter(DateTime.now())) {
        await NotificationService.scheduleReminder(
          id: _getAlarmId(prayer, 'reminder'),
          time: reminderTime,
          prayer: prayer,
          minutes: minutes,
        );
      }
    }

    if (setting['azan'] == true && time.isAfter(DateTime.now())) {
      await NotificationService.scheduleAzan(
        id: _getAlarmId(prayer, 'azan'),
        time: time,
        prayer: prayer,
      );
    }
  }

  // 5. Schedule the rescheduler for tomorrow midnight
  await NotificationService.scheduleDailyRescheduler();
}
