import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_settings.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  final List<String> prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  final Map<String, PrayerSettings> settings = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    for (final prayer in prayers) {
      final jsonStr = prefs.getString('settings_$prayer');
      if (jsonStr != null) {
        settings[prayer] = PrayerSettings.fromMap(jsonDecode(jsonStr));
      } else {
        settings[prayer] = PrayerSettings.defaults();
      }
    }

    setState(() {});
  }

  Future<void> _save(String prayer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'settings_$prayer',
      jsonEncode(settings[prayer]!.toMap()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (settings.length != prayers.length) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Notifications'),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: prayers.map(_prayerTile).toList(),
      ),
    );
  }

  Widget _prayerTile(String prayer) {
    final s = settings[prayer]!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prayer,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            SwitchListTile(
              title: const Text('Reminder'),
              value: s.reminderEnabled,
              onChanged: (v) {
                setState(() {
                  settings[prayer] = PrayerSettings(
                    reminderEnabled: v,
                    reminderMinutes: s.reminderMinutes,
                    adhanEnabled: s.adhanEnabled,
                  );
                });
                _save(prayer);
              },
            ),

            if (s.reminderEnabled)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonFormField<int>(
                  value: s.reminderMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Minutes before',
                  ),
                  items: const [5, 10, 15, 20, 25, 30]
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text('$m minutes'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      settings[prayer] = PrayerSettings(
                        reminderEnabled: s.reminderEnabled,
                        reminderMinutes: v!,
                        adhanEnabled: s.adhanEnabled,
                      );
                    });
                    _save(prayer);
                  },
                ),
              ),

            SwitchListTile(
              title: const Text('Adhan'),
              value: s.adhanEnabled,
              onChanged: (v) {
                setState(() {
                  settings[prayer] = PrayerSettings(
                    reminderEnabled: s.reminderEnabled,
                    reminderMinutes: s.reminderMinutes,
                    adhanEnabled: v,
                  );
                });
                _save(prayer);
              },
            ),
          ],
        ),
      ),
    );
  }
}
