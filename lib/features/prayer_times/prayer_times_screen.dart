import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../utils/notification_service.dart';
import '../../utils/prayer_cache.dart';
import 'package:flutter/services.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  PrayerTimes? prayerTimes;
  Timer? _timer;
  DateTime now = DateTime.now();
  String _locationName = 'Loading...';

  bool _loading = true;
  String? _permissionError;

  @override
  void initState() {
    super.initState();
    _initLocationAndPrayerTimes();

    // ⏱ Update clock only
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// ---------------- LOCATION ----------------
  Future<void> _initLocationAndPrayerTimes() async {
    final cache = PrayerCache();

    await cache.load(); // ✅ LOAD SAVED LOCATION FIRST

    if (cache.hasLocation) {
      final times = cache.calculatePrayerTimes();

      setState(() {
        prayerTimes = times;
        _locationName = cache.locationName!;
        _loading = false;
      });

      _scheduleAllNotifications();
      return;
    }

    /// ❌ First launch → explain why location is needed
    await _showLocationPermissionDialog();
  }

  Future<void> _showLocationPermissionDialog() async {
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Location Required'),
        content: const Text(
          'Your location is required to calculate accurate prayer times and Qibla direction.\n\n'
          'Please allow location access.',
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

    if (allow == true) {
      await _refreshLocation();
    } else {
      setState(() {
        _loading = false;
        _permissionError =
            'Location permission is required to show prayer times.';
      });
    }
  }

  Future<void> _refreshLocation() async {
    setState(() {
      _loading = true;
      _permissionError = null;
    });

    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) {
      setState(() => _loading = false);
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

    final times = cache.calculatePrayerTimes();

    setState(() {
      prayerTimes = times;
      _locationName = location;
      _loading = false;
    });

    _scheduleAllNotifications();
  }

  Future<bool> _handleLocationPermission() async {
    final gpsEnabled = await _ensureLocationServiceEnabled();
    if (!gpsEnabled) return false;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      setState(() {
        _permissionError =
            'Location permission was denied. Please allow it to continue.';
        _loading = false;
      });
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _permissionError =
            'Location permission is permanently denied. Enable it from settings.';
        _loading = false;
      });

      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  /// ---------------- SCHEDULING ----------------
  Future<void> _scheduleAllNotifications() async {
    if (prayerTimes == null) return;

    await NotificationService.cancelAll();

    final map = {
      'fajr': prayerTimes!.fajr,
      'dhuhr': prayerTimes!.dhuhr,
      'asr': prayerTimes!.asr,
      'maghrib': prayerTimes!.maghrib,
      'isha': prayerTimes!.isha,
    };

    int id = 100;

    map.forEach((prayer, time) async {
      final setting = NotificationService.prayerSettings[prayer]!;

      /// ⏰ Reminder
      if (setting['reminder'] == true) {
        final minutes = setting['minutesBefore'] as int;
        final reminderTime = time.subtract(Duration(minutes: minutes));

        await NotificationService.scheduleReminder(
          id: id++,
          time: reminderTime,
          prayer: prayer,
          minutes: minutes,
        );
      }

      /// 🔊 Azan
      if (setting['azan'] == true) {
        await NotificationService.scheduleAzan(
          id: id++,
          time: time,
          prayer: prayer,
        );
      }
    });
  }

  Future<bool> _ensureLocationServiceEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (enabled) return true;

    if (!mounted) return false;

    final shouldOpenSettings = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Enable Location'),
        content: const Text(
          'Location services are disabled.\n\n'
          'Please enable GPS to calculate prayer times and Qibla direction.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              SystemNavigator.pop(); // 👈 Close the app
            },
            child: const Text('Exit'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldOpenSettings == true) {
      await Geolocator.openLocationSettings();

      // Wait a moment so Android applies changes
      await Future.delayed(const Duration(seconds: 2));

      return Geolocator.isLocationServiceEnabled();
    }

    return false;
  }

  /// ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_permissionError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off, size: 90, color: Colors.red),
                const SizedBox(height: 16),
                Text(_permissionError!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _showLocationPermissionDialog,
                  child: const Text('Grant Permission'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final hijri = HijriCalendar.now();
    final nextPrayer = prayerTimes!.nextPrayer() == Prayer.none
        ? Prayer.fajr
        : prayerTimes!.nextPrayer();

    final nextPrayerTime = prayerTimes!.timeForPrayer(nextPrayer)!;
    final remaining = nextPrayerTime.difference(now);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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

  Widget _header(HijriCalendar hijri) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Updating location...')),
              );

              await _refreshLocation();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location updated ✅')),
              );
            },
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  _locationName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline, // 👈 hint clickable
                  ),
                ),
              ],
            ),
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

  /// 🕒 Circle Clock
  Widget _clockCircle() {
    return Container(
      width: 220,
      height: 220,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15)],
      ),
      child: Center(
        child: Text(
          DateFormat('hh:mm a').format(now),
          style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold),
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
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.2),
            Colors.lightBlue.withOpacity(0.2),
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${_pretty(nextPrayer.name)} at ${DateFormat('hh:mm a').format(time)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            _formatDuration(remaining),
            style: const TextStyle(color: Colors.green),
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
          margin: const EdgeInsets.all(10),
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
                  // ⏰ Reminder
                  IconButton(
                    icon: Icon(
                      Icons.alarm,
                      color: setting['reminder'] == true
                          ? Colors.green
                          : Colors.grey,
                    ),
                    onPressed: () async {
                      final minutes = await _showMinutesDialog(
                        setting['minutesBefore'] as int,
                      );
                      if (minutes != null) {
                        setting['minutesBefore'] = minutes;
                        setting['reminder'] = true;
                        setState(() {});
                        _scheduleAllNotifications();
                      }
                    },
                  ),

                  // 🔔 Azan
                  IconButton(
                    icon: Icon(
                      setting['azan'] == true
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: setting['azan'] == true
                          ? Colors.blue
                          : Colors.grey,
                    ),
                    onPressed: () {
                      setting['azan'] = !(setting['azan'] as bool);
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

  /// ---------------- HELPERS ----------------
  String _pretty(String name) => name[0].toUpperCase() + name.substring(1);

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<int?> _showMinutesDialog(int current) {
    return showDialog<int>(
      context: context,
      builder: (_) {
        int selected = current;
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Reminder Minutes'),
            content: DropdownButton<int>(
              value: selected,
              items: [5, 10, 15, 20, 25, 30]
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e min')))
                  .toList(),
              onChanged: (v) => setStateDialog(() => selected = v ?? selected),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }
}
