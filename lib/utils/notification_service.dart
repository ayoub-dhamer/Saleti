import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:just_audio/just_audio.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static final AudioPlayer _audioPlayer = AudioPlayer();

  /// Initialize notifications & timezone
  static Future<void> init() async {
    // Timezone setup
    tz.initializeTimeZones();
    final String localTimeZone = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimeZone));

    // Notification settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iOSSettings = DarwinInitializationSettings();

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _notifications.initialize(initSettings);
  }

  /// Schedule reminder or Azan
  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dateTime,
  }) async {
    final tz.TZDateTime tzTime = tz.TZDateTime.from(dateTime, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'prayer_channel',
      'Prayer Notifications',
      channelDescription: 'Reminders and Azan notifications for prayers',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(presentSound: false);

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidAllowWhileIdle: true,
    );
  }

  /// Play Azan audio
  static Future<void> playAzan() async {
    try {
      await _audioPlayer.setAsset('assets/audio/azan.mp3');
      await _audioPlayer.play();
    } catch (e) {
      print('Error playing Azan: $e');
    }
  }

  /// Cancel all notifications (optional)
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancel a single notification by ID
  static Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
