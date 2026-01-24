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

  // ✅ Ensure channel exists even in background isolate
  final androidPlugin = _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  await androidPlugin?.createNotificationChannel(
    AndroidNotificationChannel(
      channel,
      channel,
      importance: Importance.max,
      playSound: playSound,
      sound: playSound
          ? const RawResourceAndroidNotificationSound('azan')
          : null,
    ),
  );

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
      ),
    ),
  );
}

class NotificationService {
  static Map<String, Map<String, dynamic>> prayerSettings = {
    'fajr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'dhuhr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'asr': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'maghrib': {'reminder': true, 'azan': true, 'minutesBefore': 10},
    'isha': {'reminder': true, 'azan': true, 'minutesBefore': 10},
  };

  /// 🚀 Initialize notifications + channels
  static Future<void> init() async {
    await AndroidAlarmManager.initialize();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    // Initialize notifications
    await _notifications.initialize(settings);

    // Create notification channels
    const azanChannel = AndroidNotificationChannel(
      'azan_channel',
      'Azan Notifications',
      description: 'Plays azan sound at prayer time',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('azan'),
    );

    const reminderChannel = AndroidNotificationChannel(
      'reminder_channel',
      'Prayer Reminders',
      description: 'Silent prayer reminders',
      importance: Importance.high,
      playSound: false,
    );

    // Resolve Android-specific plugin
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(azanChannel);
    await androidPlugin?.createNotificationChannel(reminderChannel);

    // ✅ No requestPermission needed on Android
  }

  /// ⏰ Schedule Reminder
  static Future<void> scheduleReminder({
    required int id,
    required DateTime time,
    required String prayer,
    required int minutes,
  }) async {
    if (time.isBefore(DateTime.now())) return;

    final pretty = '${prayer[0].toUpperCase()}${prayer.substring(1)}';

    await AndroidAlarmManager.oneShotAt(
      time,
      id,
      alarmCallback,
      exact: true,
      wakeup: true,
      params: {
        'title': 'Prayer Reminder',
        'body': '$pretty in $minutes minutes',
        'channel': 'reminder_channel',
        'playSound': false,
      },
    );
  }

  /// 🔊 Schedule Azan
  static Future<void> scheduleAzan({
    required int id,
    required DateTime time,
    required String prayer,
  }) async {
    if (time.isBefore(DateTime.now())) return;

    final pretty = '${prayer[0].toUpperCase()}${prayer.substring(1)}';

    await AndroidAlarmManager.oneShotAt(
      time,
      id,
      alarmCallback,
      exact: true,
      wakeup: true,
      params: {
        'title': 'Time for Prayer',
        'body': 'It is time for $pretty prayer',
        'channel': 'azan_channel',
        'playSound': true,
      },
    );
  }

  /// 🧹 Cancel alarms safely
  static Future<void> cancelAll() async {
    for (int i = 0; i < 300; i++) {
      await AndroidAlarmManager.cancel(i);
    }
  }
}
