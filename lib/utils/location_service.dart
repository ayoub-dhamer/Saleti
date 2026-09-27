import 'package:adhan/adhan.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'notification_service.dart';
import 'prayer_cache.dart';

/// The result of a successful [LocationService.refresh] call. By the time
/// this is returned, PrayerCache() (both SharedPreferences and the
/// in-memory singleton) already reflects it, and every prayer notification
/// and azan alarm has already been rescheduled against it — callers just
/// need this to update their own on-screen state.
class LocationRefreshResult {
  final double latitude;
  final double longitude;
  final String locationName;
  final PrayerTimes prayerTimes;

  const LocationRefreshResult({
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.prayerTimes,
  });
}

/// FIXED (bug #4): PrayerTimesScreen and QiblaScreen each carried their own
/// near-identical copy of "get a fresh GPS fix, reverse-geocode it, save
/// it, recompute prayer times" — and the copies had drifted differently:
///
/// - PrayerTimesScreen's own `_refreshLocation` updated its own UI state
///   and rescheduled notifications, but never called `PrayerCache.save()`.
///   The new coordinates only ever lived in that one screen's local state —
///   the next automatic reschedule (the daily job, or a plain app restart)
///   read the old location straight back out of SharedPreferences and
///   silently undid the refresh.
/// - QiblaScreen's refresh DID save the new coordinates, but reused
///   whatever city name was already cached instead of re-geocoding, so the
///   saved coordinates and the saved name could point at two different
///   places — and it never told NotificationService to reschedule at all,
///   so prayer alarms kept using the old location until something else
///   happened to refresh them.
///
/// Both screens now go through this one method instead, so there is
/// exactly one place that fetches, geocodes, persists, recomputes, and
/// reschedules — nowhere left for the two to disagree.
class LocationService {
  LocationService._();

  static final PrayerCache _cache = PrayerCache();

  /// Throws whatever [Geolocator.getCurrentPosition] throws (permission
  /// issues, disabled location services, timeouts) — callers should keep
  /// wrapping this in their own try/catch exactly as before.
  static Future<LocationRefreshResult> refresh({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: accuracy);

    String cityName = 'Unknown Location';
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        cityName = place.locality ?? place.subAdministrativeArea ?? cityName;
      }
    } catch (_) {
      // A failed reverse-geocode shouldn't block getting a usable location —
      // fall back to the placeholder name, same as before.
    }

    // The one save every caller now shares — coordinates and the name
    // resolved *from those same coordinates* always land together.
    await _cache.save(
      lat: pos.latitude,
      lng: pos.longitude,
      locationName: cityName,
    );

    final prayerTimes = _cache.calculatePrayerTimes();
    // Re-syncs today's reminders/azan *and* the multi-day azan lookahead
    // (see NotificationService.rescheduleAllForToday) against the location
    // just saved above — this is the step QiblaScreen's refresh skipped.
    await NotificationService.rescheduleAllForToday(prayerTimes);

    return LocationRefreshResult(
      latitude: pos.latitude,
      longitude: pos.longitude,
      locationName: cityName,
      prayerTimes: prayerTimes,
    );
  }
}
