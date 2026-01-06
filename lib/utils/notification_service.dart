import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// ⚙️ Per-prayer settings: reminder and azan mute toggles
  /// Example usage:
  /// NotificationService.prayerSettings['fajr'] = {'reminder': true, 'azan': true};
  static Map<String, Map<String, bool>> prayerSettings = {
    'fajr': {'reminder': true, 'azan': true},
    'dhuhr': {'reminder': true, 'azan': true},
    'asr': {'reminder': true, 'azan': true},
    'maghrib': {'reminder': true, 'azan': true},
    'isha': {'reminder': true, 'azan': true},
  };

  static void updatePrayerSetting(String prayer, String type, bool value) {
    prayerSettings[prayer]![type] = value;
  }

  static Future<void> init() async {
    tzData.initializeTimeZones();
    tz.setLocalLocation(tz.local);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // Optional: handle tap
      },
    );
  }

  /// 🔹 Show immediate notification
  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'saleti_channel',
          'Saleti Notifications',
          channelDescription: 'Notifications for prayer times',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(id, title, body, platformDetails);
  }

  /// 🔹 Schedule a notification at a specific DateTime
  static Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime dateTime,
    int id = 0,
  }) async {
    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(dateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'saleti_channel',
          'Saleti Notifications',
          channelDescription: 'Notifications for prayer times',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
