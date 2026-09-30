import 'dart:async';

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

void main() {
  // FIXED (bug #11): the startup sequence used to be a flat chain of about
  // a dozen unguarded awaits — Hive boxes, settings, alarm scheduling,
  // permission checks. Any single one throwing (a corrupt Hive box, a
  // malformed prayer_settings JSON left over from a bad write, ...) sent
  // the exception straight out of main(): runApp() was never reached, so
  // there was no error screen, no crash report, just an indefinitely
  // blank splash. runZonedGuarded is also the standard hook point for a
  // crash reporter (Crashlytics/Sentry/etc.) — wire one in where marked
  // below once you pick one.
  runZonedGuarded(
    () async {
      await _bootstrap();
    },
    (error, stack) {
      debugPrint(
        'Uncaught error outside the Flutter framework: $error\n$stack',
      );
      // TODO: report to a crash reporting service, e.g.
      // FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter framework error: ${details.exceptionAsString()}');
    // TODO: report to a crash reporting service, e.g.
    // FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  try {
    await Hive.initFlutter();

    await _openBoxSafely<dynamic>('app');

    Hive.registerAdapter(KhatmYearAdapter());
    Hive.registerAdapter(DailyKhatmLogAdapter());
    Hive.registerAdapter(SurahGoalAdapter());

    await _openBoxSafely<KhatmYear>('khatm_years');
    await _openBoxSafely<DailyKhatmLog>('khatm_logs');
    await _openBoxSafely<SurahGoal>('surah_goals');

    await _tryStep('load PrayerCache', PrayerCache().load);
    await _tryStep(
      'load notification settings',
      NotificationService.loadSettings,
    );
    await _tryStep('load Eid offset', NotificationService.loadEidOffset);
    await _tryStep('init notifications', NotificationService.init);

    await _tryStep('init alarm manager', AndroidAlarmManager.initialize);
    await _tryStep(
      'schedule daily rescheduler',
      NotificationService.scheduleDailyRescheduler,
    );
    await _tryStep(
      'schedule reboot catch-up',
      NotificationService.scheduleRebootCatchUp,
    );
    await _tryStep(
      'schedule Friday reminder',
      NotificationService.scheduleFridayReminder,
    );

    // catch the case where the app is opened already on Eid day
    if (PrayerCache().hasLocation) {
      await _tryStep(
        'schedule Eid reminder',
        () => NotificationService.scheduleEidReminderIfApplicable(
          todaysPrayerTimes: PrayerCache().calculatePrayerTimes(),
        ),
      );
    }

    await _tryStep('load theme', ThemeController().load);

    // ------------------- Decide Entry -------------------
    final onboardingDone =
        await _tryStep('read onboarding flag', hasCompletedOnboarding) ?? false;

    var allGranted = onboardingDone;
    if (!allGranted) {
      allGranted =
          await _tryStep(
            'check critical permissions',
            _allCriticalPermissionsGranted,
          ) ??
          false;
    }

    runApp(SaletiApp(skipOnboarding: allGranted));
  } catch (e, st) {
    // FIXED (bug #11): every step above already guards itself via
    // _tryStep/_openBoxSafely, so reaching here means something truly
    // unexpected slipped through. runApp() still gets called either way —
    // an indefinitely blank splash is worse than a plain "couldn't start"
    // screen the user can at least see and report.
    debugPrint('Fatal startup error: $e\n$st');
    runApp(const _StartupErrorApp());
  }
}

/// Runs [action] and swallows any error, logging it and returning null
/// instead of letting it escape and abort the rest of startup. Most of
/// these steps are independent of each other — a failure to, say, schedule
/// the Friday reminder has no business preventing the app from opening at
/// all — so each gets its own isolated failure instead of one shared
/// all-or-nothing chain.
Future<T?> _tryStep<T>(String label, Future<T> Function() action) async {
  try {
    return await action();
  } catch (e, st) {
    debugPrint('Startup step "$label" failed (continuing): $e\n$st');
    return null;
  }
}

/// Opens a Hive box, resetting it once if it fails to open at all (a
/// corrupt box on disk, a schema mismatch after a bad shutdown, ...)
/// instead of taking down the rest of startup with it. This trades that
/// one box's data for the app still being usable — far better than a
/// permanently unrecoverable blank splash. If even the fresh box fails to
/// open, that's a real underlying problem (storage/permissions), and it's
/// left to propagate to _bootstrap's outer catch.
Future<Box<T>> _openBoxSafely<T>(String name) async {
  try {
    return await Hive.openBox<T>(name);
  } catch (e) {
    debugPrint('Hive box "$name" failed to open ($e) — resetting it.');
    try {
      await Hive.deleteBoxFromDisk(name);
    } catch (_) {
      // Best effort — fall through to the retry regardless.
    }
    return await Hive.openBox<T>(name);
  }
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

/// FIXED (bug #11): shown only if startup fails so completely that even
/// the per-step guards above didn't contain it. Deliberately depends on
/// nothing from the failed startup — no Hive, no NotificationService, no
/// ThemeController — just plain Material, so it's guaranteed to render
/// rather than risk failing itself.
class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                SizedBox(height: 16),
                Text(
                  "Saleti couldn't start",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Please close and reopen the app. If this keeps happening, '
                  'reinstalling will reset any corrupted local data.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
