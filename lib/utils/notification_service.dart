import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:audioplayers/audioplayers.dart';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

final AudioPlayer _azanPlayer = AudioPlayer();

class NotificationService {
  static Map<String, Map<String, dynamic>> prayerSettings = {
    'fajr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'dhuhr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'asr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'maghrib': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'isha': {'reminder': true, 'azan': true, 'minutesBefore': 10},
  };

  static Future<void> init() async {
    await AndroidAlarmManager.initialize();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notifications.initialize(settings);
  }

  // 🔔 Reminder Notification
  static Future<void> showReminder(String prayer, int minutes) async {
    await _notifications.show(
      prayer.hashCode,
      'Prayer Reminder',
      '$prayer in $minutes minutes',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Prayer Reminders',
          importance: Importance.high,
        ),
      ),
    );
  }

  // 🔊 Azan Notification with sound
  static Future<void> showAzan(String prayer) async {
    await _notifications.show(
      prayer.hashCode + 999,
      'Time for Prayer',
      'It is time for $prayer prayer',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'azan_channel',
          'Azan',
          importance: Importance.max,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('azan'),
        ),
      ),
    );
  }
}
