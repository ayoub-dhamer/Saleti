import 'dart:math' as NotificationImportance;

import 'package:adhan/adhan.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_foreground_task/models/android_notification_options.dart';
import 'package:flutter_foreground_task/models/foreground_task_options.dart';
import 'package:flutter_foreground_task/models/notification_channel_importance.dart';
import 'package:flutter_foreground_task/models/notification_icon_data.dart';
import 'package:flutter_foreground_task/models/notification_priority.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:saleti/utils/prayer_reminder_service.dart';
import 'features/home/home_screen.dart';
import 'utils/notification_service.dart';
import 'utils/prayer_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'azan_foreground',
      channelName: 'Azan Playback',
      channelDescription: 'Plays azan audio',

      // ✅ CORRECT ENUM
      channelImportance: NotificationChannelImportance.MAX,

      // ✅ THIS ONE IS ALREADY CORRECT
      priority: NotificationPriority.MAX,

      buttons: [NotificationButton(id: 'stop', text: 'Stop')],
    ),

    iosNotificationOptions: const IOSNotificationOptions(),

    foregroundTaskOptions: const ForegroundTaskOptions(
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  await PrayerReminderService.init();

  await PrayerCache().load();

  // ✅ Initialize notifications
  await NotificationService.loadSettings();
  await NotificationService.init();

  await AndroidAlarmManager.initialize();
  await NotificationService.scheduleDailyRescheduler();

  runApp(const SaletiApp());
}

class SaletiApp extends StatelessWidget {
  const SaletiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saleti',
      theme: ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Amiri',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
