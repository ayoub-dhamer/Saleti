import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:audioplayers/audioplayers.dart';
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

  // Audio
  final AudioPlayer _player = AudioPlayer();
  bool isPlaying = false;

  // Trigger lock for prayer
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
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

  // 🔹 PLAY AZAN
  Future<void> _playAzan() async {
    if (isPlaying) return;
    isPlaying = true;
    await _player.play(AssetSource('audio/azan.mp3'));
  }

  Future<void> _stopAzan() async {
    await _player.stop();
    isPlaying = false;
    setState(() {});
  }

  // 🔹 CHECK PRAYER TIME AND REMINDERS
  void _checkPrayerTrigger() {
    if (prayerTimes == null) return;

    final prayers = {
      'fajr': prayerTimes!.fajr,
      'dhuhr': prayerTimes!.dhuhr,
      'asr': prayerTimes!.asr,
      'maghrib': prayerTimes!.maghrib,
      'isha': prayerTimes!.isha,
    };

    prayers.forEach((name, time) {
      final setting = NotificationService.prayerSettings[name]!;

      // Pre-prayer reminder
      if (setting.reminderEnabled) {
        final reminderTime = time.subtract(
          Duration(minutes: setting.reminderMinutes),
        );
        if (now.hour == reminderTime.hour &&
            now.minute == reminderTime.minute &&
            now.second == reminderTime.second) {
          NotificationService.showNotification(
            title: 'Upcoming Prayer',
            body:
                '${_prettyPrayerName(name)} in ${setting.reminderMinutes} minutes',
          );
        }
      }

      // Prayer time notification & azan
      if (now.hour == time.hour &&
          now.minute == time.minute &&
          now.second == time.second &&
          !_triggered) {
        _triggered = true;

        if (setting.azanEnabled) _playAzan();

        NotificationService.showNotification(
          title: 'Prayer Time',
          body: 'It is time for ${_prettyPrayerName(name)}',
        );

        Timer(const Duration(seconds: 3), () => _triggered = false);
      }
    });
  }

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

    final params = CalculationParameters(fajrAngle: 18.0, ishaAngle: 17.0)
      ..madhab = Madhab.shafi;

    setState(() {
      _locationName = place.locality ?? place.administrativeArea ?? 'Unknown';

      prayerTimes = PrayerTimes(
        coordinates,
        DateComponents.from(DateTime.now()), // keep as-is
        params,
      );
    });
  }

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

  // ------------------------- UI -------------------------

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

  // ------------------------- WIDGETS -------------------------

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
                '${_prettyPrayerName(nextPrayer.name)} at ${DateFormat('HH:mm').format(time)}',
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
        final prayerKey = entry.key.toLowerCase();
        final time = entry.value;
        final isCurrent =
            currentPrayer != Prayer.none && currentPrayer.name == prayerKey;

        final setting = NotificationService.prayerSettings[prayerKey]!;

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
              // Prayer name + time
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isCurrent
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    DateFormat('hh:mm a').format(time),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),

              // Reminder & Notification icons
              Row(
                children: [
                  // Reminder
                  InkWell(
                    onTap: () async {
                      if (!setting.reminderEnabled) {
                        setting.reminderEnabled = true;
                      }
                      final newMinutes = await _showMinutesDialog(
                        setting.reminderMinutes,
                      );
                      if (newMinutes != null) {
                        setting.reminderMinutes = newMinutes;
                      }
                      setting.reminderEnabled = true;
                      setState(() {});
                      NotificationService.updatePrayerSetting(
                        prayerKey,
                        setting,
                      );
                    },
                    child: Icon(
                      Icons.alarm,
                      color: setting.reminderEnabled
                          ? Colors.green
                          : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Azan/Notification
                  IconButton(
                    onPressed: () {
                      setting.azanEnabled = !setting.azanEnabled;
                      setState(() {});
                      NotificationService.updatePrayerSetting(
                        prayerKey,
                        setting,
                      );
                    },
                    icon: Icon(
                      setting.azanEnabled
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      color: setting.azanEnabled ? Colors.blue : Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<int?> _showMinutesDialog(int currentMinutes) async {
    return showDialog<int>(
      context: context,
      builder: (context) {
        int selected = currentMinutes;
        return AlertDialog(
          title: const Text('Select reminder minutes'),
          content: DropdownButton<int>(
            value: selected,
            items: [5, 10, 15, 20, 25, 30]
                .map((e) => DropdownMenuItem(value: e, child: Text('$e min')))
                .toList(),
            onChanged: (v) {
              if (v != null) selected = v;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ------------------------- HELPERS -------------------------

  String _prettyPrayerName(String name) {
    switch (name) {
      case 'fajr':
        return 'Fajr';
      case 'dhuhr':
        return 'Dhuhr';
      case 'asr':
        return 'Asr';
      case 'maghrib':
        return 'Maghrib';
      case 'isha':
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
