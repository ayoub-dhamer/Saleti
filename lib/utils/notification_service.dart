import 'package:adhan/adhan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/prayer_times/prayer_times_screen.dart';
import '../features/prayer_times/prayer_settings_screen.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static final AudioPlayer _audioPlayer = AudioPlayer();

  /// Initialize notification plugin
  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        // Optional: handle notification tap
      },
    );
  }

  /// Schedule a reminder notification
  /// [prayer] – which prayer
  /// [prayerTime] – exact DateTime of prayer
  static Future<void> schedulePrayerReminder(
    Prayer prayer,
    DateTime prayerTime,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Load prayer settings
    final setting = await PrayerSettingsScreen.getPrayerSettings(prayer);

    if (setting.muteReminder) return; // Skip if muted

    final reminderTime = prayerTime.subtract(
      Duration(minutes: setting.reminderMinutes),
    );

    // Notification ID (unique per prayer)
    final id = prayer.index;

    final androidDetails = AndroidNotificationDetails(
      'prayer_channel',
      'Prayer Notifications',
      channelDescription: 'Reminders for prayers',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false, // sound handled manually
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      id,
      'Prayer Reminder',
      '${prayer.name} prayer in ${setting.reminderMinutes} min',
      tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  /// Trigger Azan audio at prayer time
  static Future<void> playAzan(Prayer prayer) async {
    final setting = await PrayerSettingsScreen.getPrayerSettings(prayer);
    if (setting.muteAzan) return;

    // Play Azan audio
    await _audioPlayer.play(AssetSource('azan.mp3'));
  }

  /// Cancel all scheduled reminders
  static Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }
}
