import 'package:flutter/material.dart';
import '../../core/services/location_service.dart';
import '../../core/services/prayer_time_service.dart';
import '../hijri_calendar/hijri_calendar_screen.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  double? latitude;
  double? longitude;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    try {
      final position = await LocationService.getCurrentLocation();
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(body: Center(child: Text(error!)));
    }

    final prayerTimes = PrayerTimeService.getPrayerTimes(
      latitude: latitude!,
      longitude: longitude!,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Times'),
        centerTitle: true,
        backgroundColor: Colors.green,
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: Column(
          children: [
            Text(
              'Today\'s Prayer Times',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.lightBlue[800],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _prayerCard(
                    'Fajr',
                    prayerTimes.fajr,
                    Icons.wb_sunny_outlined,
                  ),
                  _prayerCard('Sunrise', prayerTimes.sunrise, Icons.wb_sunny),
                  _prayerCard('Dhuhr', prayerTimes.dhuhr, Icons.brightness_5),
                  _prayerCard('Asr', prayerTimes.asr, Icons.brightness_6),
                  _prayerCard(
                    'Maghrib',
                    prayerTimes.maghrib,
                    Icons.nights_stay,
                  ),
                  _prayerCard('Isha', prayerTimes.isha, Icons.bedtime),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _prayerCard(String name, DateTime? time, IconData icon) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Colors.lightBlue),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(
          formatPrayerTime(time),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ),
    );
  }
}
