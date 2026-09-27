import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrayerCache {
  static final PrayerCache _instance = PrayerCache._internal();

  factory PrayerCache() => _instance;

  PrayerCache._internal();

  double? lat;

  double? lng;

  String? locationName;

  bool get hasLocation => lat != null && lng != null && locationName != null;

  /// ---------------- LOAD ----------------

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    lat = prefs.getDouble('lat');

    lng = prefs.getDouble('lng');

    locationName = prefs.getString('location');
  }

  /// ---------------- SAVE ----------------

  Future<void> save({
    required double lat,

    required double lng,

    required String locationName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setDouble('lat', lat);

    await prefs.setDouble('lng', lng);

    await prefs.setString('location', locationName);

    this.lat = lat;

    this.lng = lng;

    this.locationName = locationName;
  }

  /// ---------------- PRAYER CALC ----------------

  PrayerTimes calculatePrayerTimes() => calculatePrayerTimesFor(DateTime.now());

  /// ADDED (bug #3): lets callers compute prayer times for a day other than
  /// today — used to pre-arm native azan alarms several days ahead instead
  /// of relying solely on the (Doze-affected) midnight rescheduler to
  /// create each new day's alarms. Kept as one shared method with the same
  /// calculation method/madhab as `calculatePrayerTimes()` so the two never
  /// drift out of sync with each other.
  PrayerTimes calculatePrayerTimesFor(DateTime date) {
    final coordinates = Coordinates(lat!, lng!);

    final params = CalculationMethod.muslim_world_league.getParameters()
      ..madhab = Madhab.shafi;

    return PrayerTimes(coordinates, DateComponents.from(date), params);
  }
}
