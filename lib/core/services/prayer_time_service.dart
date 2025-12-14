import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';

class PrayerTimeService {
  static PrayerTimes getPrayerTimes({
    required double latitude,
    required double longitude,
  }) {
    final coordinates = Coordinates(latitude, longitude);

    final params = CalculationMethod.muslim_world_league.getParameters();
    params.madhab = Madhab.hanafi; // change to hanafi if needed

    final date = DateComponents.from(DateTime.now());

    return PrayerTimes(coordinates, date, params);
  }
}

String formatPrayerTime(DateTime? time) {
  if (time == null) return '--:--';
  return DateFormat.jm().format(time);
}
