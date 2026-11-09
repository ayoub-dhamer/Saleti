import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saleti/features/prayer_times/setup_onboarding_screen.dart';
import 'package:saleti/features/quran/khatm_screen.dart';
import 'package:saleti/features/quran/surah_goals_screen.dart';
import 'package:saleti/utils/exact_alarm_permission.dart';
import 'package:saleti/utils/mushaf_color_settings.dart';
import 'features/home/home_screen.dart';
import 'utils/notification_service.dart';
import 'utils/prayer_cache.dart';
import 'utils/religious_settings.dart';
import 'package:saleti/utils/theme_controller.dart';
import 'package:saleti/utils/app_theme.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  runZonedGuarded(
    () async {
      await _bootstrap();
    },
    (error, stack) {
      debugPrint(
        'Uncaught error outside the Flutter framework: $error\n$stack',
      );
    },
  );
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter framework error: ${details.exceptionAsString()}');
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

    await _tryStep('load religious settings', ReligiousSettings.load);
    await _tryStep('load PrayerCache', PrayerCache().load);
    await _tryStep(
      'load notification settings',
      NotificationService.loadSettings,
    );
    await _tryStep('load Eid offset', NotificationService.loadEidOffset);

    await _tryStep('init notifications', NotificationService.init);

    await _tryStep('load theme', ThemeController().load);

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

    await _tryStep('load Mushaf colors', MushafColorSettings().load);

    runApp(SaletiApp(skipOnboarding: allGranted));

    unawaited(_scheduleBackgroundWork());
  } catch (e, st) {
    debugPrint('Fatal startup error: $e\n$st');
    runApp(const _StartupErrorApp());
  }
}

Future<T?> _tryStep<T>(String label, Future<T> Function() action) async {
  try {
    return await action();
  } catch (e, st) {
    debugPrint('Startup step "$label" failed (continuing): $e\n$st');
    return null;
  }
}

Future<void> _scheduleBackgroundWork() async {
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

  if (PrayerCache().hasLocation) {
    await _tryStep(
      'schedule Eid reminder',
      () => NotificationService.scheduleEidReminderIfApplicable(
        todaysPrayerTimes: PrayerCache().calculatePrayerTimes(),
      ),
    );
  }
}

Future<Box<T>> _openBoxSafely<T>(String name) async {
  const attempts = 3;

  for (var i = 0; i < attempts; i++) {
    try {
      return await Hive.openBox<T>(name);
    } catch (e) {
      debugPrint(
        'Hive box "$name" failed to open (attempt ${i + 1}/$attempts): $e',
      );
      if (i < attempts - 1) {
        await Future.delayed(Duration(milliseconds: 250 * (i + 1)));
      }
    }
  }

  debugPrint('Hive box "$name" is unreadable — backing up and resetting it.');
  await _backupBoxFile(name);
  try {
    await Hive.deleteBoxFromDisk(name);
  } catch (_) {}
  return await Hive.openBox<T>(name);
}

Future<void> _backupBoxFile(String name) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${name.toLowerCase()}.hive');
    if (await file.exists()) {
      await file.copy('${file.path}.corrupt');
    }
  } catch (e) {
    debugPrint('Could not back up Hive box "$name": $e');
  }
}

Future<bool> _allCriticalPermissionsGranted() async {
  bool locationGranted = false;
  if (await Geolocator.isLocationServiceEnabled()) {
    final perm = await Geolocator.checkPermission();
    locationGranted =
        perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  final notificationGranted = await Permission.notification.isGranted;

  final alarmOk = await ExactAlarmPermission.isGranted();

  return locationGranted && notificationGranted && alarmOk;
}

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
