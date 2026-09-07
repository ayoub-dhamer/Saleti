import 'package:flutter/material.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saleti/features/prayer_times/setup_onboarding_screen.dart';
import 'package:saleti/features/quran/khatm_screen.dart';
import 'package:saleti/features/quran/surah_goals_screen.dart';
import 'package:saleti/utils/battery_optimization_permission.dart';
import 'package:saleti/utils/exact_alarm_permission.dart';
import 'features/home/home_screen.dart';
import 'utils/notification_service.dart';
import 'utils/prayer_cache.dart';
import 'package:saleti/utils/theme_controller.dart';
import 'package:saleti/utils/app_theme.dart';

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
  await NotificationService.loadEidOffset(); // ADD
  await NotificationService.init();

  await AndroidAlarmManager.initialize();
  await NotificationService.scheduleDailyRescheduler();
  await NotificationService.scheduleRebootCatchUp();
  await NotificationService.scheduleFridayReminder();

  // ADD: catch the case where the app is opened already on Eid day
  if (PrayerCache().hasLocation) {
    await NotificationService.scheduleEidReminderIfApplicable(
      todaysPrayerTimes: PrayerCache().calculatePrayerTimes(),
    );
  }

  await ThemeController().load();

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

class SaletiApp extends StatefulWidget {
  // CHANGED: was StatelessWidget
  final bool skipOnboarding;

  const SaletiApp({required this.skipOnboarding, super.key});

  @override
  State<SaletiApp> createState() => _SaletiAppState();
}

class _SaletiAppState extends State<SaletiApp> {
  final ThemeController _themeController = ThemeController();

  @override
  void initState() {
    super.initState();
    _themeController.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Saleti',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeController.flutterThemeMode,
      home: widget.skipOnboarding
          ? const HomeScreen()
          : const PermissionOnboardingScreen(),
    );
  }
}
