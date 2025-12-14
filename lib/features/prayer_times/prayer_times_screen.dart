import 'package:flutter/material.dart';
import '../../core/services/location_service.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  final LocationService _locationService = LocationService();

  String _locationText = 'Fetching location...';

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      setState(() {
        _locationText = 'Lat: ${position.latitude}, Lng: ${position.longitude}';
      });
    } catch (e) {
      setState(() {
        _locationText = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Location')),
      body: Center(child: Text(_locationText, textAlign: TextAlign.center)),
    );
  }
}
