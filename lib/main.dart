import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:saleti/features/quran/khatm_screen.dart';
import 'package:saleti/features/quran/surah_goals_screen.dart';
import 'features/home/home_screen.dart';
import 'utils/notification_service.dart';
import 'utils/prayer_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(KhatmYearAdapter());
  Hive.registerAdapter(DailyKhatmLogAdapter());

  await Hive.openBox<KhatmYear>('khatm_years');
  await Hive.openBox<DailyKhatmLog>('khatm_logs');

  Hive.registerAdapter(SurahGoalAdapter());

  await Hive.openBox<SurahGoal>('surah_goals');

  await PrayerCache().load();
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
