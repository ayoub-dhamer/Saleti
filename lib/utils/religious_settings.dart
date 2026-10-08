import 'package:adhan/adhan.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FIXED (polish #2): calculation method + madhab used to be hard-coded
/// (Muslim World League + Shafi) in four separate places. Earlier fixes
/// (bug #4, polish #1) had already consolidated every prayer-time
/// calculation in the app down to one call site —
/// PrayerCache.calculatePrayerTimesFor — without yet making it
/// configurable. This is that: a persisted, user-editable set of
/// calculation settings (method, madhab, high-latitude rule, and a
/// per-prayer minute adjustment, matching what the adhan package itself
/// supports) that PrayerCache now builds its CalculationParameters from,
/// editable from SettingsScreen.
///
/// Also covers the Hijri calendar half of the same review point: Umm
/// al-Qura's calculated dates (which the `hijri` package's HijriCalendar
/// is based on) often differ from a given mosque's local moon-sighting
/// announcement by a day. hijriDayOffset lets the user correct for that
/// without switching to a different calculation entirely.
class ReligiousSettings {
  ReligiousSettings._();

  static const _methodKey = 'calc_method';
  static const _madhabKey = 'calc_madhab';
  static const _highLatKey = 'calc_high_lat_rule';
  static const _adjKeyPrefix = 'calc_adj_';
  static const _hijriOffsetKey = 'hijri_day_offset';

  /// Order matters only for iterating all five in the settings UI; keys
  /// match adhan's own Prayer.name values (lowercase) so they can be used
  /// directly when building PrayerAdjustments below.
  static const List<String> adjustablePrayers = [
    'fajr',
    'sunrise',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];

  static CalculationMethod method = CalculationMethod.muslim_world_league;
  static Madhab madhab = Madhab.shafi;
  static HighLatitudeRule highLatitudeRule = HighLatitudeRule.twilight_angle;
  static final Map<String, int> adjustmentsMinutes = {
    for (final p in adjustablePrayers) p: 0,
  };
  static int hijriDayOffset = 0;

  static bool _loaded = false;
  static bool get isLoaded => _loaded;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final methodName = prefs.getString(_methodKey);
    if (methodName != null) {
      method = CalculationMethod.values.firstWhere(
        (m) => m.name == methodName,
        orElse: () => CalculationMethod.muslim_world_league,
      );
    }

    final madhabName = prefs.getString(_madhabKey);
    if (madhabName != null) {
      madhab = Madhab.values.firstWhere(
        (m) => m.name == madhabName,
        orElse: () => Madhab.shafi,
      );
    }

    final highLatName = prefs.getString(_highLatKey);
    if (highLatName != null) {
      highLatitudeRule = HighLatitudeRule.values.firstWhere(
        (r) => r.name == highLatName,
        orElse: () => HighLatitudeRule.twilight_angle,
      );
    }

    for (final prayer in adjustablePrayers) {
      final stored = prefs.getInt('$_adjKeyPrefix$prayer');
      if (stored != null) adjustmentsMinutes[prayer] = stored;
    }

    hijriDayOffset = prefs.getInt(_hijriOffsetKey) ?? 0;
    _loaded = true;
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_methodKey, method.name);
    await prefs.setString(_madhabKey, madhab.name);
    await prefs.setString(_highLatKey, highLatitudeRule.name);
    for (final entry in adjustmentsMinutes.entries) {
      await prefs.setInt('$_adjKeyPrefix${entry.key}', entry.value);
    }
    await prefs.setInt(_hijriOffsetKey, hijriDayOffset);
  }

  /// Builds a fresh CalculationParameters from the current settings.
  /// PrayerCache.calculatePrayerTimesFor is the only caller — every
  /// prayer-time calculation in the app goes through it.
  static CalculationParameters buildParameters() {
    final params = method.getParameters();
    params.madhab = madhab;
    params.highLatitudeRule = highLatitudeRule;
    // Mutates the method's own default adjustments object in place rather
    // than assuming `.adjustments` can be reassigned wholesale — some
    // calculation methods (see getParameters()) already set their own
    // default adjustments (e.g. Dubai's sunrise/dhuhr/asr/maghrib
    // offsets), which this layers the user's additional minutes on top of
    // rather than silently discarding.
    params.adjustments.fajr += adjustmentsMinutes['fajr']!;
    params.adjustments.sunrise += adjustmentsMinutes['sunrise']!;
    params.adjustments.dhuhr += adjustmentsMinutes['dhuhr']!;
    params.adjustments.asr += adjustmentsMinutes['asr']!;
    params.adjustments.maghrib += adjustmentsMinutes['maghrib']!;
    params.adjustments.isha += adjustmentsMinutes['isha']!;
    return params;
  }

  /// Applies hijriDayOffset by shifting the Gregorian input date before
  /// conversion — equivalent to shifting the resulting Hijri date by the
  /// same number of days. Done at this layer rather than via the `hijri`
  /// package's own HijriCalendar.adjustments/setAdjustments, which is a
  /// month-keyed map meant for fixed historical corrections to specific
  /// months, not a simple global ± day the user can nudge.
  static HijriCalendar hijriForDate(DateTime date) {
    return HijriCalendar.fromDate(date.add(Duration(days: hijriDayOffset)));
  }
}
