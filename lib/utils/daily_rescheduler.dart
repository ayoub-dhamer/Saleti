import 'package:flutter/widgets.dart';
import 'notification_service.dart';
import 'prayer_cache.dart';

@pragma('vm:entry-point')
Future<void> dailyRescheduleCallback() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.loadSettings();

  final cache = PrayerCache();
  await cache.load();

  if (!cache.hasLocation) return;

  final prayerTimes = cache.calculatePrayerTimes();

  await NotificationService.cancelPrayerAlarms();

  final map = {
    'fajr': prayerTimes.fajr,
    'dhuhr': prayerTimes.dhuhr,
    'asr': prayerTimes.asr,
    'maghrib': prayerTimes.maghrib,
    'isha': prayerTimes.isha,
  };

  int getAlarmId(String prayer, String type) {
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

    // Dart reminder
    if (setting['reminder'] == true) {
      final minutes = setting['minutesBefore'] as int;
      final reminderTime = time.subtract(Duration(minutes: minutes));
      if (reminderTime.isAfter(DateTime.now())) {
        await NotificationService.scheduleReminder(
          id: getAlarmId(prayer, 'reminder'),
          time: reminderTime,
          prayer: prayer,
          minutes: minutes,
        );
      }
    }

    // Native Azan
    if (setting['azan'] == true && time.isAfter(DateTime.now())) {
      await NotificationService.scheduleAzanNative(
        id: getAlarmId(prayer, 'azan'),
        time: time,
        prayer: prayer,
        volume: (setting['volume'] is double) ? setting['volume'] : 1.0,
        azanEnabled: setting['azan'],
      );
    }
  }

  await NotificationService.scheduleDailyRescheduler();
}
