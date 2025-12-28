import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  final List<String> prayers = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  final List<int> reminderOptions = [5, 10, 15, 20, 25, 30];

  Map<String, int> reminders = {};
  Map<String, bool> muteReminder = {};
  Map<String, bool> muteAzan = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      for (var prayer in prayers) {
        reminders[prayer] = prefs.getInt('${prayer}_reminder') ?? 10;
        muteReminder[prayer] = prefs.getBool('${prayer}_muteReminder') ?? false;
        muteAzan[prayer] = prefs.getBool('${prayer}_muteAzan') ?? false;
      }
    });
  }

  Future<void> _saveSetting(String prayer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${prayer}_reminder', reminders[prayer]!);
    await prefs.setBool('${prayer}_muteReminder', muteReminder[prayer]!);
    await prefs.setBool('${prayer}_muteAzan', muteAzan[prayer]!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Settings'),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: prayers.map((prayer) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prayer,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text("Reminder: "),
                      DropdownButton<int>(
                        value: reminders[prayer],
                        items: reminderOptions
                            .map(
                              (min) => DropdownMenuItem(
                                value: min,
                                child: Text("$min min before"),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() => reminders[prayer] = val!);
                          _saveSetting(prayer);
                        },
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mute Reminder'),
                    value: muteReminder[prayer]!,
                    onChanged: (val) {
                      setState(() => muteReminder[prayer] = val);
                      _saveSetting(prayer);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mute Azan'),
                    value: muteAzan[prayer]!,
                    onChanged: (val) {
                      setState(() => muteAzan[prayer] = val);
                      _saveSetting(prayer);
                    },
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
