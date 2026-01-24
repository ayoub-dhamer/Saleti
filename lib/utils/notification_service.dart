import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

final FlutterLocalNotificationsPlugin _notifications =
    FlutterLocalNotificationsPlugin();

/// ⚠️ Must be top-level for Android Alarm Manager
@pragma('vm:entry-point')
Future<void> alarmCallback(int id, Map<String, dynamic> params) async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);
  await _notifications.initialize(settings);

  final title = params['title'] as String;
  final body = params['body'] as String;
  final channel = params['channel'] as String;
  final playSound = params['playSound'] as bool;

  await _notifications.show(
    id,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        channel,
        channel,
        importance: Importance.max,
        priority: Priority.high,
        playSound: playSound,
        sound: playSound
            ? const RawResourceAndroidNotificationSound('azan')
            : null,
        enableVibration: playSound,
      ),
    ),
  );
}

class NotificationService {
  // Default prayer notification settings
  static Map<String, Map<String, dynamic>> prayerSettings = {
    'fajr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'dhuhr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'asr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'maghrib': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'isha': {'reminder': true, 'azan': true, 'minutesBefore': 10},
  };

  /// Initialize notifications and alarm manager
  static Future<void> init() async {
    // Initialize Android Alarm Manager
    await AndroidAlarmManager.initialize();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notifications.initialize(settings);

    // Create channels for Android
    const azanChannel = AndroidNotificationChannel(
      'azan_channel',
      'Azan Notifications',
      description: 'Plays azan sound at prayer time',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('azan'),
    );

    const reminderChannel = AndroidNotificationChannel(
      'reminder_channel',
      'Prayer Reminders',
      description: 'Silent prayer reminders',
      importance: Importance.high,
      playSound: false,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(azanChannel);
    await androidPlugin?.createNotificationChannel(reminderChannel);
  }

  /// Schedule a reminder notification (silent)
  static Future<void> scheduleReminder({
    required int id,
    required DateTime time,
    required String prayer,
    required int minutes,
  }) async {
    if (time.isBefore(DateTime.now())) return;

    await AndroidAlarmManager.oneShotAt(
      time,
      id,
      alarmCallback,
      exact: true,
      wakeup: true,
      params: {
        'title': 'Prayer Reminder',
        'body': '$prayer in $minutes minutes',
        'channel': 'reminder_channel',
        'playSound': false,
      },
    );
  }

  /// Schedule Azan notification with sound
  static Future<void> scheduleAzan({
    required int id,
    required DateTime time,
    required String prayer,
  }) async {
    if (time.isBefore(DateTime.now())) return;

    await AndroidAlarmManager.oneShotAt(
      time,
      id,
      alarmCallback,
      exact: true,
      wakeup: true,
      params: {
        'title': 'Time for Prayer',
        'body': 'It is time for $prayer prayer',
        'channel': 'azan_channel',
        'playSound': true,
      },
    );
  }

  /// Cancel all scheduled alarms (for rescheduling)
  static Future<void> cancelAll() async {
    for (int i = 0; i < 5000; i++) {
      await AndroidAlarmManager.cancel(i);
    }
  }
}
