// lib/features/prayer_times/prayer_settings.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';

class PrayerSettings {
  static const _keyPrefix = 'prayer_';

  /// Load all settings
  static Future<Map<Prayer, Map<String, dynamic>>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<Prayer, Map<String, dynamic>> settings = {};

    for (Prayer p in Prayer.values) {
      final notify = prefs.getBool('${_keyPrefix}${p.name}_notify') ?? true;
      final audio = prefs.getBool('${_keyPrefix}${p.name}_audio') ?? true;
      final minutesBefore =
          prefs.getInt('${_keyPrefix}${p.name}_minutes') ?? 10;

      settings[p] = {
        "notify": notify,
        "audio": audio,
        "minutesBefore": minutesBefore,
      };
    }
    return settings;
  }

  /// Save single prayer setting
  static Future<void> saveSetting(
    Prayer prayer,
    String key,
    dynamic value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final fullKey = '${_keyPrefix}${prayer.name}_$key';

    if (value is bool) await prefs.setBool(fullKey, value);
    if (value is int) await prefs.setInt(fullKey, value);
  }
}
