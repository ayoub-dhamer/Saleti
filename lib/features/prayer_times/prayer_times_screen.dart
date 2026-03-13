import 'dart:async';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:saleti/utils/battery_optimization_permission.dart';
import 'package:saleti/utils/exact_alarm_permission.dart';
import 'package:saleti/utils/prayer_cache.dart';
import '../../utils/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with WidgetsBindingObserver {
  PrayerTimes? prayerTimes;
  Timer? _timer;
  DateTime now = DateTime.now();

  bool _loading = true;
  bool _isFullyConfigured = true;
  String _locationName = 'Loading...';
  String? _permissionError;

  bool _batterySnackShown = false;
  bool _alarmSnackShown = false;

  final PrayerCache _cache = PrayerCache();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initializeSystemPermissions();
    _loadFromCacheOrRequest();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadFromCacheOrRequest() async {
    await _cache.load();

    if (_cache.hasLocation) {
      // ✅ Use cached data (NO GPS REQUIRED)
      final cachedPrayerTimes = _cache.calculatePrayerTimes();

      setState(() {
        prayerTimes = cachedPrayerTimes;
        _locationName = _cache.locationName!;
        _loading = false;
      });

      _scheduleAllNotifications();
    } else {
      // ❌ No cache → need location once
      await _checkPermissionAndLoad();
    }
  }

  // ----------------------------------------------------------
  // SYSTEM PERMISSIONS (battery / alarms / notifications)
  // ----------------------------------------------------------

  Future<void> _initializeSystemPermissions() async {
    await NotificationPermission.request();
    await BatteryOptimizationHelper.requestDisable();
    await ExactAlarmPermission.ensureEnabled(context);
    _checkSystemReadiness();
  }

  Future<void> _checkSystemReadiness({bool showSnackbars = false}) async {
    final batteryOk = await BatteryOptimizationHelper.isWhitelisted();
    final alarmOk = await ExactAlarmPermission.isGranted();

    if (!mounted) return;

    setState(() {
      _isFullyConfigured = batteryOk && alarmOk;
    });

    if (showSnackbars) {
      if (batteryOk && !_batterySnackShown) {
        _batterySnackShown = true;
      }
      if (alarmOk && !_alarmSnackShown) {
        _alarmSnackShown = true;
        _scheduleAllNotifications();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSystemReadiness(showSnackbars: true);
    }
  }

  // ----------------------------------------------------------
  // LOCATION + PRAYER TIMES (SINGLE ENTRY POINT)
  // ----------------------------------------------------------

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

    // ✅ Permission already granted
    await _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loading = true;
      _permissionError = null;
    });

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      setState(() {
        _loading = false;
        _permissionError =
            'Location permission is required to calculate prayer times.';
      });
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

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 🔹 Calculate PrayerTimes
      final params = CalculationMethod.muslim_world_league.getParameters();
      params.madhab = Madhab.shafi;

      final coordinates = Coordinates(pos.latitude, pos.longitude);
      final date = DateComponents.from(DateTime.now());

      final prayerTimesCalculated = PrayerTimes(coordinates, date, params);

      // 🔹 Reverse geocode to get city name
      String cityName = 'Unknown Location';
      try {
        final placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          cityName =
              place.locality ??
              place.subAdministrativeArea ??
              'Unknown Location';
        }
      } catch (_) {
        cityName = 'Unknown Location';
      }

      if (!mounted) return;

      await _cache.save(
        lat: pos.latitude,
        lng: pos.longitude,
        locationName: cityName,
      );

      setState(() {
        prayerTimes = prayerTimesCalculated;
        _locationName = cityName;
        _loading = false;
      });

      _scheduleAllNotifications();
    } catch (e) {
      setState(() {
        _loading = false;
        _permissionError = 'Unable to get your location. Please try again.';
      });
    }
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _permissionError = null;
    });

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 🔹 Calculate PrayerTimes
      final params = CalculationMethod.muslim_world_league.getParameters();
      params.madhab = Madhab.shafi;

      final coordinates = Coordinates(pos.latitude, pos.longitude);
      final date = DateComponents.from(DateTime.now());

      final refreshedPrayerTimes = PrayerTimes(coordinates, date, params);

      // 🔹 Reverse geocode to get city name
      String cityName = 'Unknown Location';
      try {
        final placemarks = await placemarkFromCoordinates(
          pos.latitude,
          pos.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          cityName =
              place.locality ??
              place.subAdministrativeArea ??
              'Unknown Location';
        }
      } catch (_) {
        cityName = 'Unknown Location';
      }

      if (!mounted) return;

      setState(() {
        prayerTimes = refreshedPrayerTimes;
        _locationName = cityName;
        _loading = false;
      });

      _scheduleAllNotifications();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _permissionError = 'Unable to get your location. Please try again.';
      });
    }
  }

  Future<void> _showLocationDialog() async {
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enable Location'),
        content: const Text(
          'Your location is required to calculate accurate prayer times.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (allow == true) {
      // User accepted → request GPS
      await _loadLocation();
      return;
    }

    // ❗ User said NO → fallback to cache if possible
    await _cache.load();

    if (_cache.hasLocation) {
      final cachedPrayerTimes = _cache.calculatePrayerTimes();

      setState(() {
        prayerTimes = cachedPrayerTimes;
        _locationName = _cache.locationName!;
        _loading = false;
        _permissionError = null;
      });

      _scheduleAllNotifications();
    } else {
      // ❌ No cache → real error
      setState(() {
        _loading = false;
        _permissionError =
            'Location permission is required to calculate prayer times.';
      });
    }
  }

  // ----------------------------------------------------------
  // NOTIFICATIONS
  // ----------------------------------------------------------

  Future<void> _scheduleAllNotifications() async {
    if (prayerTimes == null) return;

    final map = {
      'fajr': prayerTimes!.fajr,
      'dhuhr': prayerTimes!.dhuhr,
      'asr': prayerTimes!.asr,
      'maghrib': prayerTimes!.maghrib,
      'isha': prayerTimes!.isha,
    };

    for (final e in map.entries) {
      final prayer = e.key;
      final time = e.value;
      final setting = NotificationService.prayerSettings[prayer]!;

      await AndroidAlarmManager.cancel(_alarmId(prayer, 'reminder'));
      await AndroidAlarmManager.cancel(_alarmId(prayer, 'azan'));

      if (setting['reminder'] == true) {
        final m = setting['minutesBefore'] as int;
        final t = time.subtract(Duration(minutes: m));
        if (t.isAfter(DateTime.now())) {
          await NotificationService.scheduleReminder(
            id: _alarmId(prayer, 'reminder'),
            time: t,
            prayer: prayer,
            minutes: m,
          );
        }
      }

      if (setting['azan'] == true && time.isAfter(DateTime.now())) {
        await NotificationService.scheduleAzanNative(
          id: _alarmId(prayer, 'azan'),
          time: time,
          prayer: prayer,
          volume: _getVolume(setting),
        );
      } else {
        await AndroidAlarmManager.cancel(_alarmId(prayer, 'azan'));
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

  Future<void> _useCachedLocation() async {
    await _cache.load();

    if (!_cache.hasLocation) return;

    final cachedPrayerTimes = _cache.calculatePrayerTimes();

    setState(() {
      prayerTimes = cachedPrayerTimes;
      _locationName = _cache.locationName!;
      _permissionError = null;
      _loading = false;
    });

    _scheduleAllNotifications();
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_permissionError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_off, size: 72, color: Colors.red),
                  const SizedBox(height: 18),
                  const Text(
                    'Location Required',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _permissionError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loadLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1FA45B),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ),

                      // ✅ Cache-only button
                      if (_cache.hasLocation) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _useCachedLocation,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: BorderSide(color: Colors.green.shade600),
                            ),
                            child: const Text(
                              'Use previous location',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final hijri = HijriCalendar.now();
    final nextPrayer = prayerTimes!.nextPrayer() == Prayer.none
        ? Prayer.fajr
        : prayerTimes!.nextPrayer();

    DateTime nextTime = prayerTimes!.timeForPrayer(nextPrayer)!;
    if (nextTime.isBefore(now)) {
      nextTime = nextTime.add(const Duration(days: 1));
    }

    updateSaletiWidget(nextPrayer.name, DateFormat('hh:mm a').format(nextTime));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(hijri),
            const SizedBox(height: 16),
            _clockCircle(),
            const SizedBox(height: 16),
            _upcomingPrayer(nextPrayer, nextTime, nextTime.difference(now)),
            const SizedBox(height: 8),
            Expanded(child: _prayerList()),
          ],
        ),
      ),
    );
  }

  Future<void> updateSaletiWidget(String name, String time) async {
    await HomeWidget.saveWidgetData<String>('next_prayer_name', name);
    await HomeWidget.saveWidgetData<String>('next_prayer_time', time);
    await HomeWidget.updateWidget(
      name: 'PrayerWidgetProvider',
      androidName: 'PrayerWidgetProvider',
    );
  }

  String _formatDuration(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _prettyName(String name) {
    return name[0].toUpperCase() + name.substring(1);
  }

  double _getVolume(Map<String, dynamic> setting) {
    final v = setting['volume'];
    if (v is double) return v;
    if (v is int) return v.toDouble(); // safety
    return 1.0; // default volume
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
              // Display city name instead of coordinates
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
                  'Next: ${_prettyName(nextPrayer.name)}',
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
                          _prettyName(prayerKey),
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

                  Slider(
                    value: _getVolume(setting),
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${((setting['volume'] as double) * 100).round()}%',
                    onChanged: (v) async {
                      setState(() => setting['volume'] = v);
                      await NotificationService.saveSettings();
                      _scheduleAllNotifications();
                    },
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
                      final minutes = await _showDurationPickerDialog(
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
                        ? Icons.mosque
                        : Icons.mosque_outlined,
                    activeColor: Colors.blue,
                    isActive: setting['azan'] == true,
                    onTap: () async {
                      setState(() => setting['azan'] = !setting['azan']);
                      await NotificationService.saveSettings();

                      if (setting['azan'] == true) {
                        // Schedule azan
                        _scheduleAllNotifications();
                      } else {
                        // Cancel existing azan alarm for this prayer
                        await AndroidAlarmManager.cancel(
                          _alarmId(prayerKey, 'azan'),
                        );
                      }
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

  Future<int?> _showDurationPickerDialog(int currentMinutes) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _DurationPickerSheet(initialMinutes: currentMinutes),
    );
  }
}

class _DurationPickerSheet extends StatefulWidget {
  final int initialMinutes;

  const _DurationPickerSheet({required this.initialMinutes});

  @override
  State<_DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<_DurationPickerSheet> {
  static const int _loopCount = 10000;

  late FixedExtentScrollController _hoursCtrl;
  late FixedExtentScrollController _minutesCtrl;

  int hours = 0;
  int minutes = 0;

  int _centerIndex(int value, int max) {
    final base = (_loopCount ~/ 2);
    return base - (base % max) + value;
  }

  @override
  void initState() {
    super.initState();

    hours = widget.initialMinutes ~/ 60;
    minutes = widget.initialMinutes % 60;

    // ✅ Clamp to safe ranges
    hours = hours.clamp(0, 23);
    minutes = minutes.clamp(0, 59);

    _hoursCtrl = FixedExtentScrollController(
      initialItem: _centerIndex(hours, 24),
    );
    _minutesCtrl = FixedExtentScrollController(
      initialItem: _centerIndex(minutes, 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Reminder Before Prayer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _wheel(
                    label: 'Hours',
                    controller: _hoursCtrl,
                    max: 24,
                    onChanged: (v) => setState(() => hours = v),
                  ),
                  _wheel(
                    label: 'Minutes',
                    controller: _minutesCtrl,
                    max: 60,
                    onChanged: (v) => setState(() => minutes = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: () {
                Navigator.pop(context, hours * 60 + minutes);
              },
              child: const Text(
                'SET REMINDER',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wheel({
    required String label,
    required FixedExtentScrollController controller,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: CupertinoPicker.builder(
              scrollController: controller,
              itemExtent: 52,
              backgroundColor: Colors.black,
              onSelectedItemChanged: (index) {
                final value = index % max;
                onChanged(value);
              },
              itemBuilder: (_, index) {
                final value = index % max;
                return Center(
                  child: Text(
                    value.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
