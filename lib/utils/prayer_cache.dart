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
  PrayerTimes calculatePrayerTimes() {
    final coordinates = Coordinates(lat!, lng!);
    final params = CalculationParameters(fajrAngle: 18, ishaAngle: 17)
      ..madhab = Madhab.shafi;

    return PrayerTimes(
      coordinates,
      DateComponents.from(DateTime.now()),
      params,
    );
  }
}
