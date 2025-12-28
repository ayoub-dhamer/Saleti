import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';

class PrayerSettings {
  static const List<Prayer> prayers = [
    Prayer.fajr,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  ];

  static Future<Map<Prayer, Map<String, dynamic>>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<Prayer, Map<String, dynamic>> map = {};

    for (var p in prayers) {
      final notify = prefs.getBool('${p.name}_notify') ?? true;
      final audio = prefs.getBool('${p.name}_audio') ?? true;
      final minutesBefore = prefs.getInt('${p.name}_minutesBefore') ?? 10;
      map[p] = {
        "notify": notify,
        "audio": audio,
        "minutesBefore": minutesBefore,
      };
    }

    return map;
  }

  static Future<void> saveSettings(
    Prayer p,
    bool notify,
    bool audio,
    int minutesBefore,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${p.name}_notify', notify);
    await prefs.setBool('${p.name}_audio', audio);
    await prefs.setInt('${p.name}_minutesBefore', minutesBefore);
  }
}
