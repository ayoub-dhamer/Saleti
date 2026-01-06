import 'package:flutter/material.dart';
import '../../utils/notification_service.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  Map<String, Map<String, bool>> _settings = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Load saved mute settings from NotificationService
  void _loadSettings() {
    setState(() {
      _settings = Map.from(NotificationService.prayerSettings);
    });
  }

  /// Toggle reminder or Azan for a prayer
  void _toggle(String prayer, String type) {
    setState(() {
      _settings[prayer]![type] = !_settings[prayer]![type]!;
      NotificationService.updatePrayerSetting(
        prayer,
        type,
        _settings[prayer]![type]!,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

    return Scaffold(
      appBar: AppBar(title: const Text('Prayer Notifications')),
      body: ListView.builder(
        itemCount: prayers.length,
        itemBuilder: (context, index) {
          final prayer = prayers[index];
          final settings = _settings[prayer]!;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Text(
                prayer[0].toUpperCase() + prayer.substring(1),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Row(
                children: [
                  Row(
                    children: [
                      const Text('Reminder'),
                      Switch(
                        value: settings['reminder']!,
                        onChanged: (_) => _toggle(prayer, 'reminder'),
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      const Text('Azan'),
                      Switch(
                        value: settings['azan']!,
                        onChanged: (_) => _toggle(prayer, 'azan'),
                        activeColor: Colors.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
