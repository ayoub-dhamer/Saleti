import 'dart:async';

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
  /// issues, disabled location services, a timeout with nothing cached to
  /// fall back to) — callers should keep wrapping this in their own
  /// try/catch exactly as before.
  static Future<LocationRefreshResult> refresh({
    // FIXED (Battery/CPU #5): was LocationAccuracy.high. Prayer times and
    // Qibla direction only need city-level precision, not GPS-grade
    // meter-level precision — medium resolves faster and cheaper on the
    // radio for no visible difference in either feature.
    LocationAccuracy accuracy = LocationAccuracy.medium,
  }) async {
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        // FIXED (Battery/CPU #5): without a timeLimit, a weak or absent
        // GPS signal left this hanging indefinitely — the "Loading..."
        // state (and the refresh spinner) in both PrayerTimesScreen and
        // QiblaScreen would simply never resolve. geolocator's own issue
        // tracker has real reports of getCurrentPosition taking 30+
        // seconds or timing out outright on some Android 12+ devices, so
        // this is a real-world case, not a theoretical one.
        timeLimit: const Duration(seconds: 10),
      );
    } on TimeoutException {
      // FIXED (Battery/CPU #5): fall back to the last cached fix instead
      // of just failing outright — good enough for city-level prayer
      // times/qibla direction, and far better than leaving the caller
      // stuck with nothing. If there's truly nothing cached either (e.g.
      // this device has never gotten a location fix before), let the
      // original timeout propagate so the caller's existing error
      // handling shows its usual "couldn't get location" message.
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) rethrow;
      pos = last;
    }

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
