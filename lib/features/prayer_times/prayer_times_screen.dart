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

  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();

  final AudioPlayer _player = AudioPlayer();
  bool isPlaying = false;

  /// SETTINGS STORAGE
  Map<String, bool> azanEnabled = {
    "Fajr": true,
    "Dhuhr": true,
    "Asr": true,
    "Maghrib": true,
    "Isha": true,
  };

  Map<String, bool> notificationEnabled = {
    "Fajr": true,
    "Dhuhr": true,
    "Asr": true,
    "Maghrib": true,
    "Isha": true,
  };

  Map<String, bool> reminderEnabled = {
    "Fajr": false,
    "Dhuhr": false,
    "Asr": false,
    "Maghrib": false,
    "Isha": false,
  };

  Map<String, int> reminderMinutes = {
    "Fajr": 10,
    "Dhuhr": 10,
    "Asr": 10,
    "Maghrib": 10,
    "Isha": 10,
  };

  @override
  void initState() {
    super.initState();
    _initPreferences();
    _initNotifications();
    _initLocationAndPrayerTimes();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      now = DateTime.now();
      _checkPrayerTrigger();
      _checkReminderTrigger();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --------------------- PREFERENCES ---------------------------

  Future<void> _initPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    for (var p in azanEnabled.keys) {
      azanEnabled[p] = prefs.getBool("azan_$p") ?? true;
      notificationEnabled[p] = prefs.getBool("noti_$p") ?? true;
      reminderEnabled[p] = prefs.getBool("rem_$p") ?? false;
      reminderMinutes[p] = prefs.getInt("remMin_$p") ?? 10;
    }

    setState(() {});
  }

  void _savePreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    for (var p in azanEnabled.keys) {
      prefs.setBool("azan_$p", azanEnabled[p]!);
      prefs.setBool("noti_$p", notificationEnabled[p]!);
      prefs.setBool("rem_$p", reminderEnabled[p]!);
      prefs.setInt("remMin_$p", reminderMinutes[p]!);
    }
  }

  // --------------------- NOTIFICATIONS -------------------------

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
    );

    await notifications.initialize(settings);
  }

  Future<void> _sendNotification(
    String prayerName, {
    bool reminder = false,
  }) async {
    const AndroidNotificationDetails details = AndroidNotificationDetails(
      'prayer_channel',
      'Prayer Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false,
    );

    await notifications.show(
      reminder ? 2 : 1,
      reminder ? 'Prayer Reminder' : 'Prayer Time',
      reminder ? '$prayerName in a few minutes' : 'It is time for $prayerName',
      const NotificationDetails(android: details),
    );
  }

  Future<void> _playAzan() async {
    if (isPlaying) return;
    isPlaying = true;

    await _player.play(AssetSource('azan.mp3'));
  }

  Future<void> _stopAzan() async {
    await _player.stop();
    isPlaying = false;
    setState(() {});
  }

  // --------------------- PRAYER TRIGGERS -------------------------

  bool _prayerTriggered = false;
  bool _reminderTriggered = false;

  void _checkPrayerTrigger() {
    if (prayerTimes == null) return;

    final prayers = {
      'Fajr': prayerTimes!.fajr,
      'Dhuhr': prayerTimes!.dhuhr,
      'Asr': prayerTimes!.asr,
      'Maghrib': prayerTimes!.maghrib,
      'Isha': prayerTimes!.isha,
    };

    for (var entry in prayers.entries) {
      String pName = entry.key;
      DateTime pTime = entry.value;

      if (now.hour == pTime.hour &&
          now.minute == pTime.minute &&
          now.second == pTime.second &&
          !_prayerTriggered) {
        _prayerTriggered = true;

        if (notificationEnabled[pName]!) _sendNotification(pName);
        if (azanEnabled[pName]!) _playAzan();

        Timer(const Duration(seconds: 5), () => _prayerTriggered = false);
      }
    }
  }

  void _checkReminderTrigger() {
    if (prayerTimes == null) return;

    final prayers = {
      'Fajr': prayerTimes!.fajr,
      'Dhuhr': prayerTimes!.dhuhr,
      'Asr': prayerTimes!.asr,
      'Maghrib': prayerTimes!.maghrib,
      'Isha': prayerTimes!.isha,
    };

    for (var entry in prayers.entries) {
      String pName = entry.key;
      DateTime pTime = entry.value;

      int minutesBefore = reminderMinutes[pName]!;
      DateTime reminderTime = pTime.subtract(Duration(minutes: minutesBefore));

      if (reminderEnabled[pName]! &&
          now.hour == reminderTime.hour &&
          now.minute == reminderTime.minute &&
          now.second == reminderTime.second &&
          !_reminderTriggered) {
        _reminderTriggered = true;

        _sendNotification(pName, reminder: true);

        Timer(const Duration(seconds: 5), () => _reminderTriggered = false);
      }
    }
  }

  // --------------------- GPS + PRAYER -------------------------

  Future<void> _initLocationAndPrayerTimes() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    final position = await Geolocator.getCurrentPosition();

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    final place = placemarks.first;

    final coordinates = Coordinates(position.latitude, position.longitude);

    final params = CalculationMethod.muslim_world_league.getParameters()
      ..madhab = Madhab.shafi; // Maliki & Shafi use the same Asr rule

    setState(() {
      _locationName = '${place.locality ?? place.administrativeArea ?? ''}';

      prayerTimes = PrayerTimes(
        coordinates,
        DateComponents.from(DateTime.now()),
        params,
      );
    });
  }

  Future<bool> _handleLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // --------------------- UI -------------------------

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
      appBar: AppBar(
        title: const Text("Prayer Times"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettingsSheet,
          ),
        ],
      ),

      body: Column(
        children: [
          _header(hijri),
          _clock(),
          _upcomingPrayer(nextPrayer, nextPrayerTime, remaining),
          Expanded(child: _prayerList()),
          if (isPlaying)
            ElevatedButton(
              onPressed: _stopAzan,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Stop Azan"),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _header(HijriCalendar hijri) {
    return Padding(
      padding: const EdgeInsets.all(16),
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

  // 🕰️ CLOCK
  Widget _clock() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: Center(
        child: Text(
          DateFormat('hh:mm a').format(now),
          style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // 🔔 UPCOMING PRAYER
  Widget _upcomingPrayer(Prayer nextPrayer, DateTime time, Duration remaining) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.25),
            Colors.blue.withOpacity(0.25),
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
                "Upcoming Prayer",
                style: TextStyle(color: Colors.green),
              ),
              const SizedBox(height: 4),
              Text(
                "${_prettyPrayerName(nextPrayer)} at ${DateFormat('HH:mm').format(time)}",
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

  // 📋 PRAYER LIST
  Widget _prayerList() {
    final prayers = {
      'Fajr': prayerTimes!.fajr,
      'Sunrise': prayerTimes!.sunrise,
      'Dhuhr': prayerTimes!.dhuhr,
      'Asr': prayerTimes!.asr,
      'Maghrib': prayerTimes!.maghrib,
      'Isha': prayerTimes!.isha,
    };

    final currentPrayer = prayerTimes!.currentPrayer();

    return ListView(
      children: prayers.entries.map((entry) {
        bool isCurrent = currentPrayer.name == entry.key.toLowerCase();

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
              Text(
                DateFormat('hh:mm a').format(entry.value),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --------------------- SETTINGS BOTTOM SHEET -------------------------

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => _settingsPanel(controller),
      ),
    );
  }

  Widget _settingsPanel(ScrollController s) {
    List<String> prayers = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"];
    List<int> options = [5, 10, 15, 20, 25, 30];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        controller: s,
        children: [
          const Text(
            "Prayer Settings",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          ...prayers.map((p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),

                  // Azan
                  SwitchListTile(
                    title: const Text("Azan Sound"),
                    value: azanEnabled[p]!,
                    onChanged: (v) {
                      azanEnabled[p] = v;
                      _savePreferences();
                      setState(() {});
                    },
                  ),

                  // Notification
                  SwitchListTile(
                    title: const Text("Notification"),
                    value: notificationEnabled[p]!,
                    onChanged: (v) {
                      notificationEnabled[p] = v;
                      _savePreferences();
                      setState(() {});
                    },
                  ),

                  // Reminder
                  SwitchListTile(
                    title: const Text("Reminder Before Prayer"),
                    value: reminderEnabled[p]!,
                    onChanged: (v) {
                      reminderEnabled[p] = v;
                      _savePreferences();
                      setState(() {});
                    },
                  ),

                  if (reminderEnabled[p]!) ...[
                    const SizedBox(height: 8),
                    const Text(
                      "Reminder Interval",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    DropdownButton<int>(
                      value: reminderMinutes[p],
                      items: options
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text("$m min before"),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        reminderMinutes[p] = v!;
                        _savePreferences();
                        setState(() {});
                      },
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // --------------------- HELPERS -------------------------

  String _prettyPrayerName(Prayer p) {
    switch (p) {
      case Prayer.fajr:
        return "Fajr";
      case Prayer.sunrise:
        return "Sunrise";
      case Prayer.dhuhr:
        return "Dhuhr";
      case Prayer.asr:
        return "Asr";
      case Prayer.maghrib:
        return "Maghrib";
      case Prayer.isha:
        return "Isha";
      default:
        return "";
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }
}
