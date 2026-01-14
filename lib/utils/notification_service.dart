import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;

/// Handles per-prayer notifications and Azan playback
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Prayer settings: reminder + azan + minutes before
  static Map<String, Map<String, dynamic>> prayerSettings = {
    'fajr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'dhuhr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'asr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'maghrib': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'isha': {'reminder': true, 'azan': true, 'minutesBefore': 10},
  };

  static void updatePrayerSetting(
    String prayer,
    Map<String, dynamic> newSettings,
  ) {
    prayerSettings[prayer] = newSettings;
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

  /// Show simple reminder notification
  static Future<void> showReminder({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'prayer_reminder_channel',
      'Prayer Reminders',
      channelDescription: 'Reminder notifications before prayer',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Schedule Azan notification with custom sound
  static Future<void> scheduleAzan({
    required String prayer,
    required DateTime dateTime,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'azan_channel',
      'Azan Notifications',
      channelDescription: 'Azan at prayer time',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('azan'),
      fullScreenIntent: true, // optional: shows screen if needed
      autoCancel: true,
    );

    await _notifications.zonedSchedule(
      prayer.hashCode,
      'Prayer Time',
      'It is time for $prayer',
      tz.TZDateTime.from(dateTime, tz.local),
      NotificationDetails(android: androidDetails),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule both pre-prayer reminders and Azan
  static Future<void> schedulePrayerNotifications(
    String prayer,
    DateTime prayerTime,
  ) async {
    final settings = prayerSettings[prayer]!;

    // Reminder before prayer
    if (settings['reminder'] == true) {
      final minutes = settings['minutesBefore'] as int;
      final reminderTime = prayerTime.subtract(Duration(minutes: minutes));
      if (reminderTime.isAfter(DateTime.now())) {
        await showReminder(
          title: 'Upcoming Prayer',
          body: '$prayer in $minutes minutes',
          id: prayer.hashCode + 1,
        );
      }
    }

    // Schedule Azan
    if (settings['azan'] == true && prayerTime.isAfter(DateTime.now())) {
      await scheduleAzan(prayer: prayer, dateTime: prayerTime);
    }
  }
}
