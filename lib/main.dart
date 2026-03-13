import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saleti/features/prayer_times/permission_gate.dart';
import 'package:saleti/features/prayer_times/prayer_times_screen.dart';
import 'package:saleti/features/prayer_times/setup_onboarding_screen.dart';
import 'package:saleti/features/quran/khatm_screen.dart';
import 'package:saleti/features/quran/surah_goals_screen.dart';
import 'package:saleti/utils/battery_optimization_helper.dart';
import 'package:saleti/utils/exact_alarm_permission.dart';
import 'package:saleti/utils/onboarding_helper.dart';
import 'features/home/home_screen.dart';
import 'utils/notification_service.dart';
import 'utils/prayer_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('app');

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

  // ------------------- Decide Entry -------------------
  final onboardingDone = await hasCompletedOnboarding();
  final allGranted = onboardingDone || await _allCriticalPermissionsGranted();

  runApp(SaletiApp(skipOnboarding: allGranted));
}

/// ------------------- CHECK CRITICAL PERMISSIONS -------------------
Future<bool> _allCriticalPermissionsGranted() async {
  // Location
  bool locationGranted = false;
  if (await Geolocator.isLocationServiceEnabled()) {
    final perm = await Geolocator.checkPermission();
    locationGranted =
        perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  // Notifications
  final notificationGranted = await Permission.notification.isGranted;

  // Battery Optimization
  final batteryOk = await BatteryOptimizationHelper.isWhitelisted();

  // Exact Alarm
  final alarmOk = await ExactAlarmPermission.isGranted();

  return locationGranted && notificationGranted && batteryOk && alarmOk;
}

class SaletiApp extends StatelessWidget {
  final bool skipOnboarding;

  const SaletiApp({required this.skipOnboarding, super.key});

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
      home: skipOnboarding
          ? const HomeScreen()
          : const PermissionOnboardingScreen(),
    );
  }
}
