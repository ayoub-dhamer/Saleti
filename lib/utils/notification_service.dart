import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;

class PrayerSettings {
  bool reminderEnabled;
  int reminderMinutes;
  bool azanEnabled;

  PrayerSettings({
    this.reminderEnabled = true,
    this.reminderMinutes = 10,
    this.azanEnabled = true,
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// ⚙️ Per-prayer settings
  static Map<String, PrayerSettings> prayerSettings = {
    'fajr': PrayerSettings(),
    'dhuhr': PrayerSettings(),
    'asr': PrayerSettings(),
    'maghrib': PrayerSettings(),
    'isha': PrayerSettings(),
  };

  static void updatePrayerSetting(String prayer, PrayerSettings settings) {
    prayerSettings[prayer] = settings;
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
