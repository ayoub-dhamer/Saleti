import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_times_screen.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();

  /// 🔹 Retrieve saved prayer settings
  static Future<PrayerSetting> getPrayerSettings(Prayer prayer) async {
    final prefs = await SharedPreferences.getInstance();
    final keyPrefix = prayer.name.toLowerCase();

    final muteReminder = prefs.getBool('${keyPrefix}_mute_reminder') ?? false;
    final muteAzan = prefs.getBool('${keyPrefix}_mute_azan') ?? false;
    final reminderMinutes = prefs.getInt('${keyPrefix}_reminder_minutes') ?? 10;

    return PrayerSetting(
      muteReminder: muteReminder,
      muteAzan: muteAzan,
      reminderMinutes: reminderMinutes,
    );
  }
}

/// Model for a prayer’s settings
class PrayerSetting {
  final bool muteReminder;
  final bool muteAzan;
  final int reminderMinutes;

  PrayerSetting({
    required this.muteReminder,
    required this.muteAzan,
    required this.reminderMinutes,
  });
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  final Map<Prayer, PrayerSetting> _settings = {};

  @override
  void initState() {
    super.initState();
    _loadAllSettings();
  }

  Future<void> _loadAllSettings() async {
    for (var prayer in Prayer.values) {
      final setting = await PrayerSettingsScreen.getPrayerSettings(prayer);
      _settings[prayer] = setting;
    }
    setState(() {});
  }

  Future<void> _saveSetting(Prayer prayer, PrayerSetting setting) async {
    final prefs = await SharedPreferences.getInstance();
    final keyPrefix = prayer.name.toLowerCase();

    await prefs.setBool('${keyPrefix}_mute_reminder', setting.muteReminder);
    await prefs.setBool('${keyPrefix}_mute_azan', setting.muteAzan);
    await prefs.setInt(
      '${keyPrefix}_reminder_minutes',
      setting.reminderMinutes,
    );

    _settings[prayer] = setting;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_settings.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prayer Settings'),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: Prayer.values.map((prayer) {
          final setting = _settings[prayer]!;
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
                    prayer.name.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Mute Reminder'),
                      const Spacer(),
                      Switch(
                        value: setting.muteReminder,
                        onChanged: (v) {
                          _saveSetting(
                            prayer,
                            PrayerSetting(
                              muteReminder: v,
                              muteAzan: setting.muteAzan,
                              reminderMinutes: setting.reminderMinutes,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('Mute Azan'),
                      const Spacer(),
                      Switch(
                        value: setting.muteAzan,
                        onChanged: (v) {
                          _saveSetting(
                            prayer,
                            PrayerSetting(
                              muteReminder: setting.muteReminder,
                              muteAzan: v,
                              reminderMinutes: setting.reminderMinutes,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Reminder Minutes'),
                      const Spacer(),
                      DropdownButton<int>(
                        value: setting.reminderMinutes,
                        items: [5, 10, 15, 20, 25, 30]
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text('$e min'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            _saveSetting(
                              prayer,
                              PrayerSetting(
                                muteReminder: setting.muteReminder,
                                muteAzan: setting.muteAzan,
                                reminderMinutes: v,
                              ),
                            );
                          }
                        },
                      ),
                    ],
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
