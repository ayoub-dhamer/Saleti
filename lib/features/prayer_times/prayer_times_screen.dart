import 'dart:async';
import 'dart:io';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:saleti/utils/battery_optimization_helper.dart';
import 'package:saleti/utils/exact_alarm_permission.dart';
import '../../utils/notification_service.dart';
import '../../utils/prayer_cache.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with WidgetsBindingObserver {
  // Permission Tracking Flags
  bool _waitingForBatterySetting = false;
  bool _waitingForAlarmSetting = false;
  bool _isFullyConfigured = true;

  PrayerTimes? prayerTimes;
  Timer? _timer;
  DateTime now = DateTime.now();
  String _locationName = 'Loading...';
  bool _loading = true;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _triggerPermissionRequests();
    });

    _initLocationAndPrayerTimes();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  /// ✅ Logic: Triggered when returning from Android Settings
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionsStatus();
    }
  }

  /// ✅ Checks both permissions and updates the UI banner
  Future<void> _checkSystemReadiness() async {
    bool batteryOk = await BatteryOptimizationHelper.isWhitelisted();
    bool alarmOk = await ExactAlarmPermission.isGranted();

    if (mounted) {
      setState(() {
        _isFullyConfigured = batteryOk && alarmOk;
      });
    }
  }

  Future<void> updateSaletiWidget(String name, String time) async {
    // 1. Save data to shared preferences that Kotlin can see
    await HomeWidget.saveWidgetData<String>('next_prayer_name', name);
    await HomeWidget.saveWidgetData<String>('next_prayer_time', time);

    // 2. Trigger the update
    // 'androidName' must match the Class Name "PrayerWidgetProvider"
    await HomeWidget.updateWidget(
      name: 'PrayerWidgetProvider',
      androidName: 'PrayerWidgetProvider',
    );
  }

  /// ✅ Sequential Permission Flow
  Future<void> _triggerPermissionRequests() async {
    // 1. Notifications
    await NotificationPermission.request();

    if (!mounted) return;

    // 2. Battery Optimization
    setState(() => _waitingForBatterySetting = true);
    await BatteryOptimizationHelper.requestDisable(context);

    // 3. Exact Alarm
    if (mounted) {
      setState(() => _waitingForAlarmSetting = true);
      await ExactAlarmPermission.ensureEnabled(context);
    }
  }

  /// ✅ Verified status logic (Re-check & Success snackbars)
  Future<void> _checkPermissionsStatus() async {
    // Check Battery
    if (_waitingForBatterySetting) {
      bool isBatteryOk = await BatteryOptimizationHelper.isWhitelisted();
      if (isBatteryOk && mounted) {
        setState(() => _waitingForBatterySetting = false);
        _showSuccessSnackBar('✅ Battery optimization disabled!');
      }
    }

    // Check Exact Alarm
    if (_waitingForAlarmSetting) {
      bool isAlarmOk = await ExactAlarmPermission.isGranted();
      if (isAlarmOk && mounted) {
        setState(() => _waitingForAlarmSetting = false);
        _showSuccessSnackBar('⏰ Exact alarms enabled!');
        _scheduleAllNotifications();
      }
    }

    // Refresh the general configuration state
    _checkSystemReadiness();
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- LOCATION LOGIC (UNCHANGED) ---

  Future<void> _initLocationAndPrayerTimes() async {
    final cache = PrayerCache();
    await cache.load();
    if (!mounted) return;
    if (cache.hasLocation) {
      _applyPrayerTimes(cache);
      return;
    }
    await _showLocationPermissionDialog();
  }

  void _applyPrayerTimes(PrayerCache cache) {
    final times = cache.calculatePrayerTimes();
    if (!mounted) return;
    setState(() {
      prayerTimes = times;
      _locationName = cache.locationName!;
      _loading = false;
    });
    _scheduleAllNotifications();
  }

  Future<void> _showLocationPermissionDialog() async {
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Location Required'),
        content: const Text(
          'Your location is required for accurate prayer times.\nPlease allow access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (allow == true) {
      await _refreshLocation();
    } else {
      setState(() {
        _loading = false;
        _permissionError = 'Location permission required.';
      });
    }
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _permissionError = null;
    });
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    final location =
        placemarks.first.locality ??
        placemarks.first.administrativeArea ??
        'Unknown';
    final cache = PrayerCache();
    await cache.save(
      lat: position.latitude,
      lng: position.longitude,
      locationName: location,
    );
    _applyPrayerTimes(cache);
  }

  Future<bool> _handleLocationPermission() async {
    final gpsEnabled = await _ensureLocationServiceEnabled();
    if (!gpsEnabled) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return false;
    if (permission == LocationPermission.denied) {
      setState(() => _permissionError = 'Location denied.');
      return false;
    }
    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }
    return true;
  }

  // --- SCHEDULING ---

  int _alarmId(String prayer, String type) {
    const base = {
      'fajr': 1000,
      'dhuhr': 2000,
      'asr': 3000,
      'maghrib': 4000,
      'isha': 5000,
    };
    return base[prayer]! + (type == 'azan' ? 1 : 2);
  }

  Future<void> _scheduleAllNotifications() async {
    if (prayerTimes == null) return;
    final map = {
      'fajr': prayerTimes!.fajr,
      'dhuhr': prayerTimes!.dhuhr,
      'asr': prayerTimes!.asr,
      'maghrib': prayerTimes!.maghrib,
      'isha': prayerTimes!.isha,
    };

    for (final entry in map.entries) {
      final prayer = entry.key;
      final time = entry.value;
      final setting = NotificationService.prayerSettings[prayer]!;

      await AndroidAlarmManager.cancel(_alarmId(prayer, 'reminder'));
      await AndroidAlarmManager.cancel(_alarmId(prayer, 'azan'));

      if (setting['reminder'] == true) {
        final minutes = setting['minutesBefore'] as int;
        final reminderTime = time.subtract(Duration(minutes: minutes));
        if (reminderTime.isAfter(DateTime.now())) {
          await NotificationService.scheduleReminder(
            id: _alarmId(prayer, 'reminder'),
            time: reminderTime,
            prayer: prayer,
            minutes: minutes,
          );
        }
      }

      if (setting['azan'] == true && time.isAfter(DateTime.now())) {
        await NotificationService.scheduleAzan(
          id: _alarmId(prayer, 'azan'),
          time: time,
          prayer: prayer,
        );
      }
    }
  }

  Future<bool> _ensureLocationServiceEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (enabled) return true;
    if (!mounted) return false;
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enable Location'),
        actions: [
          TextButton(
            onPressed: () => SystemNavigator.pop(),
            child: const Text('Exit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (res == true) {
      await Geolocator.openLocationSettings();
      return true;
    }
    return false;
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    _checkSystemReadiness();

    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_permissionError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 90, color: Colors.red),
              Text(_permissionError!),
              ElevatedButton(
                onPressed: _showLocationPermissionDialog,
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    final hijri = HijriCalendar.now();
    final nextPrayer = prayerTimes!.nextPrayer() == Prayer.none
        ? Prayer.fajr
        : prayerTimes!.nextPrayer();
    DateTime nextPrayerTime = prayerTimes!.timeForPrayer(nextPrayer)!;
    if (nextPrayerTime.isBefore(now)) {
      nextPrayerTime = nextPrayerTime.add(const Duration(days: 1));
    }
    final remaining = nextPrayerTime.difference(now);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ⚠️ WARNING BANNER
            if (!_isFullyConfigured)
              GestureDetector(
                onTap: _triggerPermissionRequests,
                child: Container(
                  width: double.infinity,
                  color: Colors.orange.shade50,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Background settings not optimized. Tap to fix.',
                          style: TextStyle(
                            color: Colors.deepOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: Colors.orange.shade800,
                      ),
                    ],
                  ),
                ),
              ),
            _header(hijri),
            const SizedBox(height: 16),
            _clockCircle(),
            const SizedBox(height: 16),
            _upcomingPrayer(nextPrayer, nextPrayerTime, remaining),
            const SizedBox(height: 8),
            Expanded(child: _prayerList()),
          ],
        ),
      ),
    );
  }

  // --- SUB-WIDGETS ---

  Widget _header(HijriCalendar hijri) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _refreshLocation,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _locationName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} AH',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(DateFormat('EEEE d MMM y').format(DateTime.now())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _clockCircle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Image.asset(
              'assets/images/mosque.png',
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  DateFormat('HH:mm').format(now),
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _upcomingPrayer(Prayer nextPrayer, DateTime time, Duration remaining) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.green.withOpacity(0.1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Next: ${_pretty(nextPrayer.name)} at ${DateFormat('hh:mm a').format(time)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            _formatDuration(remaining),
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _prayerList() {
    final prayers = {
      'fajr': prayerTimes!.fajr,
      'dhuhr': prayerTimes!.dhuhr,
      'asr': prayerTimes!.asr,
      'maghrib': prayerTimes!.maghrib,
      'isha': prayerTimes!.isha,
    };
    return ListView(
      children: prayers.entries.map((entry) {
        final setting = NotificationService.prayerSettings[entry.key]!;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pretty(entry.key),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(DateFormat('hh:mm a').format(entry.value)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      setting['reminder'] == true
                          ? Icons.alarm_on
                          : Icons.alarm_off,
                      color: setting['reminder'] == true
                          ? Colors.green
                          : Colors.grey,
                    ),
                    onPressed: () async {
                      setting['reminder'] = !setting['reminder'];
                      await NotificationService.saveSettings();
                      setState(() {});
                      _scheduleAllNotifications();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      setting['azan'] == true
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: setting['azan'] == true
                          ? Colors.blue
                          : Colors.grey,
                    ),
                    onPressed: () async {
                      setting['azan'] = !setting['azan'];
                      await NotificationService.saveSettings();
                      setState(() {});
                      _scheduleAllNotifications();
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _pretty(String name) => name[0].toUpperCase() + name.substring(1);
  String _formatDuration(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class NotificationPermission {
  static Future<void> request() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }
}
