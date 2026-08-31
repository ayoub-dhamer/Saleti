import 'dart:async';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:saleti/utils/battery_optimization_permission.dart';
import 'package:saleti/utils/exact_alarm_permission.dart';
import 'package:saleti/utils/prayer_cache.dart';
import 'package:saleti/utils/special_day_helper.dart';
import '../../utils/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PrayerTimesScreen extends StatefulWidget {
  final bool isActive;

  const PrayerTimesScreen({super.key, this.isActive = true});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with WidgetsBindingObserver {
  PrayerTimes? prayerTimes;
  Timer? _timer;
  DateTime now = DateTime.now();

  bool _loading = true;
  String _locationName = 'Loading...';
  String? _permissionError;

  bool _batterySnackShown = false;
  bool _alarmSnackShown = false;

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  final PrayerCache _cache = PrayerCache();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initializeSystemPermissions();
    _loadFromCacheOrRequest();

    if (widget.isActive) _startTicker();
  }

  @override
  void didUpdateWidget(covariant PrayerTimesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startTicker();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopTicker();
    }
  }

  void _startTicker() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = DateTime.now());
    });
  }

  void _stopTicker() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    super.dispose();
  }

  Future<void> _loadFromCacheOrRequest() async {
    await _cache.load();

    if (_cache.hasLocation) {
      final cachedPrayerTimes = _cache.calculatePrayerTimes();

      setState(() {
        prayerTimes = cachedPrayerTimes;
        _locationName = _cache.locationName!;
        _loading = false;
      });

      _scheduleAllNotifications();
    } else {
      await _checkPermissionAndLoad();
    }
  }

  // ----------------------------------------------------------
  // SYSTEM PERMISSIONS
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

    setState(() {});

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
  // LOCATION + PRAYER TIMES
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

      final params = CalculationMethod.muslim_world_league.getParameters();
      params.madhab = Madhab.shafi;

      final coordinates = Coordinates(pos.latitude, pos.longitude);
      final date = DateComponents.from(DateTime.now());

      final prayerTimesCalculated = PrayerTimes(coordinates, date, params);

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
    HapticFeedback.lightImpact();

    setState(() {
      _loading = true;
      _permissionError = null;
    });

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final params = CalculationMethod.muslim_world_league.getParameters();
      params.madhab = Madhab.shafi;

      final coordinates = Coordinates(pos.latitude, pos.longitude);
      final date = DateComponents.from(DateTime.now());

      final refreshedPrayerTimes = PrayerTimes(coordinates, date, params);

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
      await _loadLocation();
      return;
    }

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
          azanEnabled: setting['azan'],
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
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryGreen, secondaryGreen],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.mosque, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: primaryGreen),
              const SizedBox(height: 12),
              const Text(
                'Finding prayer times…',
                style: TextStyle(color: Colors.black45, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_permissionError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 16),
                  child: child,
                ),
              ),
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
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_off_rounded,
                        size: 48,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Location Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _permissionError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loadLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Retry'),
                          ),
                        ),
                        if (_cache.hasLocation) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _useCachedLocation,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
        ),
      );
    }

    final hijri = HijriCalendar.now();
    final eidName = SpecialDayHelper.eidNameFor(DateTime.now());
    final nextPrayer = prayerTimes!.nextPrayer() == Prayer.none
        ? Prayer.fajr
        : prayerTimes!.nextPrayer();

    DateTime nextTime = prayerTimes!.timeForPrayer(nextPrayer)!;
    if (nextTime.isBefore(now)) {
      nextTime = nextTime.add(const Duration(days: 1));
    }

    final previousTime = _getPreviousPrayerTime(nextPrayer, nextTime); // ADD

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            _header(hijri),
            if (eidName != null) _eidBanner(eidName), // ADD
            const SizedBox(height: 16),
            _clockCard(),
            const SizedBox(height: 16),
            _upcomingPrayer(
              // CHANGED: now passes previousTime
              nextPrayer,
              nextTime,
              previousTime,
              nextTime.difference(now),
            ),
            const SizedBox(height: 8),
            Expanded(child: _prayerList()),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _prettyName(String name) {
    if (name == 'dhuhr' && SpecialDayHelper.isJumuah(DateTime.now())) {
      return "Jumu'ah";
    }
    return name[0].toUpperCase() + name.substring(1);
  }

  double _getVolume(Map<String, dynamic> setting) {
    final v = setting['volume'];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return 1.0;
  }

  /// Returns the actual DateTime of the prayer immediately preceding `next`.
  /// Handles the Isha -> Fajr wraparound by pulling Isha from the correct
  /// calendar day relative to `nextTime`.
  DateTime _getPreviousPrayerTime(Prayer next, DateTime nextTime) {
    const order = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    final nextName = next.name.toLowerCase();
    final idx = order.indexOf(nextName);
    final safeIdx = idx == -1 ? 0 : idx;
    final prevName = order[(safeIdx - 1 + order.length) % order.length];

    // If next prayer is Fajr, the previous one (Isha) belongs to the day before.
    final isWrap = nextName == 'fajr';
    final targetDate = isWrap
        ? DateTime(
            nextTime.year,
            nextTime.month,
            nextTime.day,
          ).subtract(const Duration(days: 1))
        : DateTime(nextTime.year, nextTime.month, nextTime.day);

    final params = CalculationMethod.muslim_world_league.getParameters();
    params.madhab = Madhab.shafi;
    final coordinates = Coordinates(_cache.lat!, _cache.lng!);
    final pt = PrayerTimes(
      coordinates,
      DateComponents.from(targetDate),
      params,
    );

    switch (prevName) {
      case 'fajr':
        return pt.fajr;
      case 'dhuhr':
        return pt.dhuhr;
      case 'asr':
        return pt.asr;
      case 'maghrib':
        return pt.maghrib;
      case 'isha':
        return pt.isha;
      default:
        return pt.fajr;
    }
  }

  // ---------------- HEADER ----------------

  Widget _header(HijriCalendar hijri) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _refreshLocation,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: primaryGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Tap to refresh',
                          style: TextStyle(fontSize: 10, color: Colors.black38),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // CHANGED: back to the plain Column, no white card wrapper
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

  // ---------------- CLOCK CARD ----------------

  Widget _clockCard() {
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

  // ---------------- UPCOMING PRAYER ----------------

  Widget _upcomingPrayer(
    Prayer nextPrayer,
    DateTime time,
    DateTime previousTime, // ADD
    Duration remaining,
  ) {
    // Mathematically accurate progress: how far `now` is between the
    // previous prayer and the next one.
    final totalWindow = time.difference(previousTime).inSeconds; // CHANGED
    final elapsed = now.difference(previousTime).inSeconds; // CHANGED
    final progress = totalWindow > 0
        ? (elapsed / totalWindow).clamp(0.0, 1.0)
        : 0.0; // CHANGED: guards against div-by-zero / bad data

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => CircularProgressIndicator(
                      value: value,
                      strokeWidth: 3,
                      backgroundColor: Colors.white.withOpacity(0.25),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const Icon(
                    Icons.timer_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
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
                fontSize: 19,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- PRAYER LIST ----------------

  Widget _prayerList() {
    final now = DateTime.now();

    final prayers = {
      'fajr': prayerTimes!.fajr,
      'dhuhr': prayerTimes!.dhuhr,
      'asr': prayerTimes!.asr,
      'maghrib': prayerTimes!.maghrib,
      'isha': prayerTimes!.isha,
    };

    Prayer next = prayerTimes!.nextPrayer();
    DateTime nextTime;

    if (next == Prayer.none) {
      next = Prayer.fajr;

      final tomorrow = now.add(const Duration(days: 1));
      final params = CalculationMethod.muslim_world_league.getParameters();
      params.madhab = Madhab.shafi;

      final tomorrowPrayerTimes = PrayerTimes(
        Coordinates(_cache.lat!, _cache.lng!),
        DateComponents.from(tomorrow),
        params,
      );

      nextTime = tomorrowPrayerTimes.fajr;
    } else {
      nextTime = prayerTimes!.timeForPrayer(next)!;
      if (nextTime.isBefore(now)) {
        final tomorrow = now.add(const Duration(days: 1));
        final params = CalculationMethod.muslim_world_league.getParameters();
        params.madhab = Madhab.shafi;
        final tomorrowPrayerTimes = PrayerTimes(
          Coordinates(_cache.lat!, _cache.lng!),
          DateComponents.from(tomorrow),
          params,
        );
        nextTime = tomorrowPrayerTimes.fajr;
        next = Prayer.fajr;
      }
    }

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

            final isNext = next.name.toLowerCase() == prayerKey;
            final alarmId = _alarmId(prayerKey, 'azan');

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isNext
                    ? primaryGreen.withOpacity(0.045)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: isNext
                              ? Colors.green.shade700
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Prayer name & time
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
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

                      // Volume slider
                      SizedBox(
                        width: 116,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                activeTrackColor: const Color(0xFF6EC6FF),
                                inactiveTrackColor: const Color(
                                  0xFF6EC6FF,
                                ).withOpacity(0.3),
                                thumbColor: const Color(0xFF6EC6FF),
                                overlayColor: const Color(
                                  0xFF6EC6FF,
                                ).withOpacity(0.2),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                              ),
                              child: Slider(
                                value: _getVolume(setting),
                                min: 0.0,
                                max: 1.0,
                                divisions: 10,
                                label:
                                    '${((_getVolume(setting)) * 100).round()}%',
                                onChanged: (v) {
                                  // Update UI live only — no I/O per drag frame
                                  setState(() => setting['volume'] = v);
                                },
                                onChangeEnd: (v) async {
                                  // Heavy work happens once, on release
                                  await NotificationService.saveSettings();
                                  if (setting['azan'] == true) {
                                    await NotificationService.scheduleAzanNative(
                                      id: alarmId,
                                      time: prayerTime,
                                      prayer: prayerKey,
                                      volume: v,
                                      azanEnabled: true,
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 4),

                      // Reminder toggle
                      _actionIcon(
                        icon: setting['reminder'] == true
                            ? Icons.alarm_on
                            : Icons.alarm_off,
                        activeColor: Colors.green,
                        isActive: setting['reminder'] == true,
                        onTap: () async {
                          HapticFeedback.selectionClick();
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

                      // Azan toggle
                      _actionIcon(
                        icon: setting['azan'] == true
                            ? Icons.mosque
                            : Icons.mosque_outlined,
                        activeColor: Colors.blue,
                        isActive: setting['azan'] == true,
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          setState(() => setting['azan'] = !setting['azan']);
                          await NotificationService.saveSettings();

                          if (setting['azan'] == true) {
                            await NotificationService.scheduleAzanNative(
                              id: alarmId,
                              time: prayerTime,
                              prayer: prayerKey,
                              volume: _getVolume(setting),
                              azanEnabled: true,
                            );
                          } else {
                            await NotificationService.cancelAzan(alarmId);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _eidBanner(String eidName) {
    final estimate = SpecialDayHelper.estimatedEidTime(
      prayerTimes!,
      offsetMinutes: NotificationService.eidOffsetMinutes,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE9A319), Color(0xFFF4C542)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE9A319).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.celebration_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$eidName Mubarak!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _showEidOffsetPicker(context),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Estimated prayer time: ${DateFormat('hh:mm a').format(estimate)} '
            '(sunrise + ${NotificationService.eidOffsetMinutes} min)',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'This is an estimate, not official — confirm with your local mosque.',
            style: TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }

  Future<void> _showEidOffsetPicker(BuildContext context) async {
    int tempValue = NotificationService.eidOffsetMinutes;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Eid Time Offset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Minutes after sunrise your local mosque typically holds Eid prayer.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Slider(
                value: tempValue.toDouble(),
                min: 0,
                max: 60,
                divisions: 12,
                label: '$tempValue min',
                activeColor: primaryGreen,
                onChanged: (v) => setDialogState(() => tempValue = v.round()),
              ),
              Text(
                '$tempValue minutes',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, tempValue),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await NotificationService.saveEidOffset(result);
      setState(() {}); // refresh the banner with the new offset
    }
  }

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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            icon,
            key: ValueKey(icon),
            size: 20,
            color: isActive ? activeColor : Colors.grey.shade400,
          ),
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
