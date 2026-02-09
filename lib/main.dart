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
import 'features/home/home_screen.dart';
import 'utils/notification_service.dart';
import 'utils/prayer_cache.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'azan_foreground',
      channelName: 'Azan Playback',
      channelDescription: 'Plays azan audio',
      channelImportance: NotificationChannelImportance.MAX,
      priority: NotificationPriority.MAX,
      buttons: [const NotificationButton(id: 'stop', text: 'Stop')],
      // If foregroundServiceType isn't found here, it's because it's
      // handled via the TaskOptions in 6.5.0
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: ForegroundTaskOptions(
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

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
