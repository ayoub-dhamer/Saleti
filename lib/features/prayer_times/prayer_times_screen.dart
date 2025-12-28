import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // Notifications
  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  // Audio
  final AudioPlayer _player = AudioPlayer();
  bool isPlaying = false;

  // Triggered reminders/Azan
  Set<String> _triggeredReminders = {};

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _initLocationAndPrayerTimes();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      setState(() => now = DateTime.now());
      _checkPrayerTrigger(); // 🔔 Check if it's prayer time
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  // 📌 INITIALIZE NOTIFICATIONS
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await notifications.initialize(settings);
  }

  // 📌 SEND NOTIFICATION
  Future<void> _sendNotification(String title) async {
    const AndroidNotificationDetails details = AndroidNotificationDetails(
      'prayer_channel',
      'Prayer Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false, // sound handled manually by audio player
    );

    await notifications.show(
      0,
      'Prayer Reminder',
      title,
      NotificationDetails(android: details),
    );
  }

  // 📌 PLAY AZAN
  Future<void> _playAzan() async {
    if (isPlaying) return;
    isPlaying = true;
    await _player.play(AssetSource('azan.mp3'));
  }

  // 🛑 STOP AZAN
  Future<void> _stopAzan() async {
    await _player.stop();
    isPlaying = false;
    setState(() {});
  }

  // 📍 PRAYER TIME TRIGGER
  void _checkPrayerTrigger() async {
    if (prayerTimes == null) return;
    final prefs = await SharedPreferences.getInstance();

    final prayers = {
      'Fajr': prayerTimes!.fajr,
      'Dhuhr': prayerTimes!.dhuhr,
      'Asr': prayerTimes!.asr,
      'Maghrib': prayerTimes!.maghrib,
      'Isha': prayerTimes!.isha,
    };

    final now = DateTime.now();

    prayers.forEach((prayerName, prayerTime) {
      // Load per-prayer settings
      final reminderMinutes = prefs.getInt('${prayerName}_reminder') ?? 10;
      final muteReminder = prefs.getBool('${prayerName}_muteReminder') ?? false;
      final muteAzan = prefs.getBool('${prayerName}_muteAzan') ?? false;

      // Reminder trigger time
      final reminderTime = prayerTime.subtract(
        Duration(minutes: reminderMinutes),
      );

      // Trigger reminder notification
      if (!_triggeredReminders.contains('${prayerName}_reminder') &&
          now.hour == reminderTime.hour &&
          now.minute == reminderTime.minute &&
          now.second == reminderTime.second) {
        _triggeredReminders.add('${prayerName}_reminder');

        if (!muteReminder) {
          _sendNotification('$prayerName in $reminderMinutes min');
        }
      }

      // Trigger Azan at prayer time
      if (!_triggeredReminders.contains('${prayerName}_azan') &&
          now.hour == prayerTime.hour &&
          now.minute == prayerTime.minute &&
          now.second == prayerTime.second) {
        _triggeredReminders.add('${prayerName}_azan');

        if (!muteAzan) {
          _playAzan();
        }
      }

      // Reset triggers after 1 minute to allow next day
      Timer(const Duration(minutes: 1), () {
        _triggeredReminders.remove('${prayerName}_reminder');
        _triggeredReminders.remove('${prayerName}_azan');
      });
    });
  }

  // 📍 INIT GPS + PRAYER TIMES
  Future<void> _initLocationAndPrayerTimes() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    final place = placemarks.first;

    final coordinates = Coordinates(position.latitude, position.longitude);

    final params = CalculationMethod.muslim_world_league.getParameters()
      ..madhab = Madhab.shafi;

    setState(() {
      _locationName = place.locality ?? place.administrativeArea ?? 'Unknown';

      prayerTimes = PrayerTimes(
        coordinates,
        DateComponents.from(DateTime.now()),
        params,
      );
    });
  }

  // 🔐 LOCATION PERMISSION
  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  @override
  Widget build(BuildContext context) {
    if (prayerTimes == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
            _clock(),
            const SizedBox(height: 16),
            _upcomingPrayer(nextPrayer, nextPrayerTime, remaining),
            const SizedBox(height: 8),
            Expanded(child: _prayerList()),
            if (isPlaying)
              ElevatedButton(
                onPressed: _stopAzan,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Stop Azan"),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ------------------------- UI COMPONENTS -----------------------------

  Widget _header(HijriCalendar hijri) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                _locationName,
                style: const TextStyle(
                  fontSize: 16,
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

  Widget _clock() {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upcoming Prayer',
                style: TextStyle(color: Colors.green),
              ),
              const SizedBox(height: 4),
              Text(
                '${_prettyPrayerName(nextPrayer)} at ${DateFormat('HH:mm').format(time)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            _formatDuration(remaining),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _prayerList() {
    final prayersMap = {
      'Fajr': prayerTimes!.fajr,
      'Dhuhr': prayerTimes!.dhuhr,
      'Asr': prayerTimes!.asr,
      'Maghrib': prayerTimes!.maghrib,
      'Isha': prayerTimes!.isha,
    };

    final currentPrayer = prayerTimes!.currentPrayer();

    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        final prefs = snapshot.data;

        return ListView(
          children: prayersMap.entries.map((entry) {
            final prayerName = entry.key;
            final time = entry.value;

            final isCurrent =
                currentPrayer != Prayer.none &&
                currentPrayer.name.toLowerCase() == prayerName.toLowerCase();

            final reminderMinutes =
                prefs?.getInt('${prayerName}_reminder') ?? 10;
            final muteReminder =
                prefs?.getBool('${prayerName}_muteReminder') ?? false;
            final muteAzan = prefs?.getBool('${prayerName}_muteAzan') ?? false;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isCurrent
                    ? Colors.green.withOpacity(0.15)
                    : Colors.white,
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 5),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prayerName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('hh:mm a').format(time),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Reminder: ${muteReminder ? "Muted" : "$reminderMinutes min before"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          muteReminder
                              ? Icons.notifications_off
                              : Icons.notifications,
                          color: Colors.orange,
                        ),
                        onPressed: () async {
                          if (prefs == null) return;
                          await prefs.setBool(
                            '${prayerName}_muteReminder',
                            !muteReminder,
                          );
                          setState(() {});
                        },
                        tooltip: 'Toggle Reminder',
                      ),
                      IconButton(
                        icon: Icon(
                          muteAzan ? Icons.volume_off : Icons.volume_up,
                          color: Colors.blue,
                        ),
                        onPressed: () async {
                          if (prefs == null) return;
                          await prefs.setBool(
                            '${prayerName}_muteAzan',
                            !muteAzan,
                          );
                          setState(() {});
                        },
                        tooltip: 'Toggle Azan',
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ------------------------- HELPERS -----------------------------
  String _prettyPrayerName(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return 'Fajr';
      case Prayer.sunrise:
        return 'Sunrise';
      case Prayer.dhuhr:
        return 'Dhuhr';
      case Prayer.asr:
        return 'Asr';
      case Prayer.maghrib:
        return 'Maghrib';
      case Prayer.isha:
        return 'Isha';
      default:
        return '';
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
