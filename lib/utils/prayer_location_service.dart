import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:adhan/adhan.dart';
import '../utils/prayer_cache.dart';

class PrayerLocationResult {
  final PrayerTimes prayerTimes;
  final String locationName;

  PrayerLocationResult({required this.prayerTimes, required this.locationName});
}

class PrayerLocationService {
  /// 🔑 SINGLE ENTRY POINT

  /// 🔄 Force refresh (manual tap)
  static Future<PrayerLocationResult> refreshPrayerTimes() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied.');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    final location =
        placemarks.first.locality ??
        placemarks.first.administrativeArea ??
        'Unknown';

    final cache = PrayerCache();
    await cache.save(
      lat: position.latitude,
      lng: position.longitude,
      locationName: location,
    );

    return PrayerLocationResult(
      prayerTimes: cache.calculatePrayerTimes(),
      locationName: location,
    );
  }
}
