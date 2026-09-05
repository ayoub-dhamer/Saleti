import 'package:hijri/hijri_calendar.dart';
import 'package:adhan/adhan.dart';

class SpecialDayHelper {
  static bool isJumuah(DateTime date) => date.weekday == DateTime.friday;

  static String? eidNameFor(DateTime date) {
    final hijri = HijriCalendar.fromDate(date);
    if (hijri.hMonth == 10 && hijri.hDay == 1) return 'Eid al-Fitr';
    if (hijri.hMonth == 12 && hijri.hDay == 10) return 'Eid al-Adha';
    return null;
  }

  static String prettyPrayerName(String prayerKey, DateTime date) {
    if (prayerKey == 'dhuhr' && isJumuah(date)) {
      return "Jumu'ah";
    }
    return prayerKey[0].toUpperCase() + prayerKey.substring(1);
  }

  /// A rough, non-authoritative estimate of Eid prayer time —
  /// sunrise + offset minutes. Communities vary widely (commonly
  /// 15-30 min after sunrise), so this is a guide only.
  static DateTime estimatedEidTime(
    PrayerTimes prayerTimes, {
    int offsetMinutes = 20,
  }) {
    return prayerTimes.sunrise.add(Duration(minutes: offsetMinutes));
  }
}
