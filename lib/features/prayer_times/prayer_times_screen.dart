import 'dart:async';
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

  // Session flags to prevent repeat snackbars
  bool _batteryMessageShown = false;
  bool _alarmMessageShown = false;

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

    // ✅ Launch sequential permission and location flow
    _initializeApp();

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

  /// ✅ Orchestrates the launch sequence
  Future<void> _initializeApp() async {
    // 1. Request Notification/Battery/Alarm permissions (System stuff)
    await _triggerPermissionRequests();

    // 2. Location Logic (The Qibla way)
    await _checkPermissionAndLoad();
  }

  /// ✅ Logic exactly like Qibla: Checks if we should show a dialog first
  Future<void> _checkPermissionAndLoad() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _loading = false;
        _permissionError = 'Location service is disabled. Please enable GPS.';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      // Show the custom dialog before the native system prompt
      await _showLocationDialog();
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _loading = false;
        _permissionError =
            'Location permission is permanently denied. Please enable it from settings.';
      });
      return;
    }

    // ✅ Permission already exists, just load
    await _refreshLocation();
  }

  Future<void> _showLocationDialog() async {
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Enable Location'),
          content: const Text(
            'We need your location to calculate prayer times accurately for your current city.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Enable'),
            ),
          ],
        );
      },
    );

    if (allow == true) {
      // User clicked Enable, now trigger native request
      await _refreshLocation();
    } else {
      setState(() {
        _loading = false;
        _permissionError =
            'Location access is required to show local prayer times.';
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSystemReadiness(showSnackbars: true);
    }
  }

  /// ✅ Checks both permissions and updates the UI banner
  Future<void> _checkSystemReadiness({bool showSnackbars = false}) async {
    bool batteryOk = await BatteryOptimizationHelper.isWhitelisted();
    bool alarmOk = await ExactAlarmPermission.isGranted();

    if (!mounted) return;

    setState(() {
      _isFullyConfigured = batteryOk && alarmOk;
    });

    if (showSnackbars) {
      if (_waitingForBatterySetting && batteryOk && !_batteryMessageShown) {
        setState(() {
          _waitingForBatterySetting = false;
          _batteryMessageShown = true;
        });
      }

      if (_waitingForAlarmSetting && alarmOk && !_alarmMessageShown) {
        setState(() {
          _waitingForAlarmSetting = false;
          _alarmMessageShown = true;
        });
        _scheduleAllNotifications();
      }
    }
  }

  /// ✅ Sequential Permission Flow
  Future<void> _triggerPermissionRequests() async {
    await NotificationPermission.request();

    if (!mounted) return;

    setState(() {
      _waitingForBatterySetting = true;
    });

    await BatteryOptimizationHelper.requestDisable(context);

    if (mounted) {
      setState(() => _waitingForAlarmSetting = true);
      await ExactAlarmPermission.ensureEnabled(context);
    }
  }

  // --- LOCATION LOGIC ---

  Future<void> _initLocationAndPrayerTimes() async {
    if (!mounted) return;
    setState(() => _loading = true);

    // 1. Hardware GPS + App Permission Check
    bool hasAccess = await _handleLocationPermission();
    if (!hasAccess) {
      if (mounted) {
        setState(() {
          _loading = false;
          _permissionError = 'Location & GPS access required for prayer times.';
        });
      }
      return;
    }

    // 2. Load from Cache or Refresh
    final cache = PrayerCache();
    await cache.load();

    if (cache.hasLocation) {
      _applyPrayerTimes(cache);
    } else {
      await _refreshLocation();
    }
  }

  Future<bool> _handleLocationPermission() async {
    // Check if GPS hardware is ON
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      bool opened = await _ensureLocationServiceEnabled();
      if (!opened) return false;
      // Re-verify after potential settings change
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }

    // Check App Level Permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _permissionError = null;
    });

    // Handle native permission request here if still denied
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() {
        _loading = false;
        _permissionError =
            'Location permission denied. Prayer times cannot be calculated.';
      });
      return;
    }

    try {
      // Actual Position Fetching
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

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
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _permissionError = 'Error fetching location: $e';
        });
      }
    }
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

  // --- SCHEDULING & ALARMS ---

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

    await NotificationService.scheduleDailyRescheduler();
  }

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

  // --- UTILS ---

  Future<bool> _ensureLocationServiceEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (enabled) return true;
    if (!mounted) return false;

    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Enable Location (GPS)'),
            content: const Text(
              'GPS is required for precise prayer calculation.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Exit'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                  Navigator.pop(context, true);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _pretty(String name) => name[0].toUpperCase() + name.substring(1);
  String _formatDuration(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> updateSaletiWidget(String name, String time) async {
    await HomeWidget.saveWidgetData<String>('next_prayer_name', name);
    await HomeWidget.saveWidgetData<String>('next_prayer_time', time);
    await HomeWidget.updateWidget(
      name: 'PrayerWidgetProvider',
      androidName: 'PrayerWidgetProvider',
    );
  }

  // --- UI BUILDING ---

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_permissionError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off, size: 90, color: Colors.red),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_permissionError!, textAlign: TextAlign.center),
              ),
              ElevatedButton(
                onPressed: _checkPermissionAndLoad,
                child: const Text('Retry Permission'),
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
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
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
                        color: Colors.orange,
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

  // (Helper widgets like _header, _clockCircle, _upcomingPrayer, _prayerList, _showMinutesDialog
  // remain the same as your previous implementation)

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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next: ${_pretty(nextPrayer.name)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'At ${DateFormat('hh:mm a').format(time)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatDuration(remaining),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 0.5,
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

    final next = prayerTimes!.nextPrayer();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          itemCount: prayers.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
          itemBuilder: (context, index) {
            final prayerKey = prayers.keys.elementAt(index);
            final prayerTime = prayers.values.elementAt(index);
            final setting = NotificationService.prayerSettings[prayerKey]!;
            final isNext = next.name == prayerKey;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  // Highlight indicator for the next prayer
                  Container(
                    width: 4,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isNext ? Colors.green : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pretty(prayerKey),
                          style: TextStyle(
                            fontWeight: isNext
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 17,
                            color: isNext
                                ? Colors.green.shade700
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat('hh:mm a').format(prayerTime),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Compact Action Buttons
                  _actionIcon(
                    icon: setting['reminder'] == true
                        ? Icons.alarm_on
                        : Icons.alarm_off,
                    activeColor: Colors.green,
                    isActive: setting['reminder'] == true,
                    onTap: () async {
                      setState(
                        () => setting['reminder'] = !setting['reminder'],
                      );
                      await NotificationService.saveSettings();
                      _scheduleAllNotifications();
                    },
                    onLongPress: () async {
                      HapticFeedback.heavyImpact();
                      final minutes = await _showMinutesDialog(
                        setting['minutesBefore'] as int,
                      );
                      if (minutes != null) {
                        setState(() {
                          setting['minutesBefore'] = minutes;
                          setting['reminder'] = true;
                        });
                        await NotificationService.saveSettings();
                        _scheduleAllNotifications();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _actionIcon(
                    icon: setting['azan'] == true
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    activeColor: Colors.blue,
                    isActive: setting['azan'] == true,
                    onTap: () async {
                      setState(() => setting['azan'] = !setting['azan']);
                      await NotificationService.saveSettings();
                      _scheduleAllNotifications();
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // Custom Helper for Elegant Buttons
  Widget _actionIcon({
    required IconData icon,
    required Color activeColor,
    required bool isActive,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withOpacity(0.12) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? activeColor : Colors.grey.shade400,
        ),
      ),
    );
  }

  Future<int?> _showMinutesDialog(int current) {
    return showDialog<int>(
      context: context,
      builder: (context) {
        int selected = current;
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Reminder Timer'),
            content: DropdownButton<int>(
              value: selected,
              isExpanded: true,
              items: [5, 10, 15, 20, 25, 30]
                  .map(
                    (m) => DropdownMenuItem(
                      value: m,
                      child: Text('$m Minutes before'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setStateDialog(() => selected = v ?? selected),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('SAVE'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NotificationPermission {
  static Future<void> request() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }
}
