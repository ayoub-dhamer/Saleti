import 'package:flutter/widgets.dart';
import 'notification_service.dart';
import 'prayer_cache.dart';

@pragma('vm:entry-point')
Future<void> dailyRescheduleCallback() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.loadSettings();
  await NotificationService.loadEidOffset(); // ADD — needed for the offset value

  final cache = PrayerCache();
  await cache.load();

  if (!cache.hasLocation) return;

  await NotificationService.cancelPrayerAlarms();
  await NotificationService.rescheduleAllForToday(
    cache.calculatePrayerTimes(),
  ); // ADD
}
