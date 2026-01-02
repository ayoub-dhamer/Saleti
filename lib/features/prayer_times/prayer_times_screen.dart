import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/notification_service.dart';

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

  // Per-prayer mute settings
  Map<Prayer, bool> mutePrayer = {
    Prayer.fajr: false,
    Prayer.dhuhr: false,
    Prayer.asr: false,
    Prayer.maghrib: false,
    Prayer.isha: false,
  };

  @override
  void initState() {
    super.initState();
    _initLocationAndPrayerTimes();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => now = DateTime.now());
      _checkPrayerTrigger();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Initialize GPS + PrayerTimes
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

    final params = CalculationMethod.muslimWorldLeague.getParameters()
      ..madhab = Madhab.shafi;

    setState(() {
      _locationName = place.locality ?? place.administrativeArea ?? 'Unknown';
      prayerTimes = PrayerTimes(
        coordinates,
        DateComponents.from(DateTime.now()),
        params,
      );
    });

    // Schedule reminders for all prayers
    _scheduleAllReminders();
  }

  /// Check prayer trigger and play Azan
  bool _triggered = false;
  void _checkPrayerTrigger() {
    if (prayerTimes == null) return;

    final prayers = {
      Prayer.fajr: prayerTimes!.fajr,
      Prayer.dhuhr: prayerTimes!.dhuhr,
      Prayer.asr: prayerTimes!.asr,
      Prayer.maghrib: prayerTimes!.maghrib,
      Prayer.isha: prayerTimes!.isha,
    };

    prayers.forEach((prayer, time) async {
      if (now.hour == time.hour &&
          now.minute == time.minute &&
          now.second == time.second &&
          !_triggered &&
          !mutePrayer[prayer]!) {
        _triggered = true;

        // Play Azan
        await NotificationService.playAzan();

        // Optional: show local notification
        await NotificationService.scheduleReminder(
          id: prayer.index,
          title: 'Prayer Time',
          body: 'It is time for ${_prettyPrayerName(prayer)}',
          dateTime: now,
        );

        Timer(const Duration(seconds: 3), () => _triggered = false);
      }
    });
  }

  /// Schedule reminders (5,10,15,20,25,30 minutes before)
  Future<void> _scheduleAllReminders() async {
    if (prayerTimes == null) return;

    final reminders = [5, 10, 15, 20, 25, 30]; // minutes before
    final prayers = {
      Prayer.fajr: prayerTimes!.fajr,
      Prayer.dhuhr: prayerTimes!.dhuhr,
      Prayer.asr: prayerTimes!.asr,
      Prayer.maghrib: prayerTimes!.maghrib,
      Prayer.isha: prayerTimes!.isha,
    };

    int notificationId = 100; // starting ID for reminders

    for (var entry in prayers.entries) {
      final prayer = entry.key;
      final time = entry.value;

      for (var minutesBefore in reminders) {
        final reminderTime = time.subtract(Duration(minutes: minutesBefore));

        if (reminderTime.isAfter(DateTime.now()) && !mutePrayer[prayer]!) {
          await NotificationService.scheduleReminder(
            id: notificationId++,
            title: 'Upcoming Prayer',
            body: '${_prettyPrayerName(prayer)} in $minutesBefore minutes',
            dateTime: reminderTime,
          );
        }
      }
    }
  }

  /// Location permission
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

  /// ------------------ UI BUILD ------------------
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
          ],
        ),
      ),
    );
  }

  // ------------------ UI COMPONENTS ------------------

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
    final prayers = {
      'Fajr': prayerTimes!.fajr,
      'Dhuhr': prayerTimes!.dhuhr,
      'Asr': prayerTimes!.asr,
      'Maghrib': prayerTimes!.maghrib,
      'Isha': prayerTimes!.isha,
    };

    final currentPrayer = prayerTimes!.currentPrayer();

    return ListView(
      children: prayers.entries.map((entry) {
        final isCurrent =
            currentPrayer != Prayer.none &&
            currentPrayer.name.toLowerCase() == entry.key.toLowerCase();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isCurrent ? Colors.green.withOpacity(0.15) : Colors.white,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.key,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Row(
                children: [
                  Text(
                    DateFormat('hh:mm a').format(entry.value),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  // Toggle mute for prayer
                  IconButton(
                    icon: Icon(
                      mutePrayer[_stringToPrayer(entry.key)]!
                          ? Icons.volume_off
                          : Icons.volume_up,
                      color: Colors.green,
                    ),
                    onPressed: () {
                      setState(() {
                        mutePrayer[_stringToPrayer(entry.key)] =
                            !mutePrayer[_stringToPrayer(entry.key)]!;
                      });
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

  // ------------------ HELPERS ------------------

  String _prettyPrayerName(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return 'Fajr';
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

  Prayer _stringToPrayer(String s) {
    switch (s.toLowerCase()) {
      case 'fajr':
        return Prayer.fajr;
      case 'dhuhr':
        return Prayer.dhuhr;
      case 'asr':
        return Prayer.asr;
      case 'maghrib':
        return Prayer.maghrib;
      case 'isha':
        return Prayer.isha;
      default:
        return Prayer.fajr;
    }
  }
}
