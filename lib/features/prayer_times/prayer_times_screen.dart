import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:saleti/utils/battery_optimization_permission.dart';
import 'package:saleti/utils/exact_alarm_permission.dart';
import 'package:saleti/utils/location_service.dart';
import 'package:saleti/utils/prayer_cache.dart';
import 'package:saleti/utils/special_day_helper.dart';
import 'package:saleti/utils/theme_controller.dart';
import 'package:saleti/widgets/icon_action.dart';
import '../../utils/notification_service.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PrayerTimesScreen extends StatefulWidget {
  final bool isActive;

  const PrayerTimesScreen({super.key, this.isActive = true});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with WidgetsBindingObserver {
  PrayerTimes? prayerTimes;
  Timer? _timer;
  DateTime now = DateTime.now();

  // Calendar date that `prayerTimes` was computed for, and the prayer that
  // was "next" the last time we rebuilt. Used by the ticker to notice when
  // the day rolls over or a prayer's time passes, without forcing a full
  // rebuild every second.
  DateTime? _prayerTimesDate;
  Prayer? _lastKnownNextPrayer;

  bool _loading = true;
  String _locationName = 'Loading...';
  String? _permissionError;

  // FIXED (bug #6): replaces the old _batterySnackShown/_alarmSnackShown
  // flags, which fed a snackbar that was apparently planned but never
  // actually built — _checkSystemReadiness computed status and then
  // showed nothing. These now drive a persistent banner (see
  // _readinessBanner) instead. Null means "not checked yet" (avoids a
  // flash of a warning before the first check resolves).
  bool? _notificationOk;
  bool? _batteryOk;
  bool? _alarmOk;

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  final PrayerCache _cache = PrayerCache();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // FIXED (bug #6): this used to call _initializeSystemPermissions(),
    // which re-requested the battery-optimization exemption and
    // relaunched the exact-alarm settings screen on *every* cold start
    // until granted. Unlike a normal runtime permission, Android doesn't
    // rate-limit either of those after a first refusal, so a user who'd
    // already said no once got interrupted by the same two system
    // prompts every single time they opened the app. Notifications are a
    // normal permission the OS itself only ever prompts for once, so
    // that request stays automatic; battery optimization and exact alarm
    // are now only ever actively requested from onboarding, or from a
    // deliberate tap on the readiness banner below (see _readinessBanner)
    // — this just checks current status.
    NotificationPermission.request();
    _checkSystemReadiness();
    _loadFromCacheOrRequest();

    if (widget.isActive) _startTicker();
  }

  @override
  void didUpdateWidget(covariant PrayerTimesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startTicker();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopTicker();
    }
  }

  final ValueNotifier<DateTime> _nowNotifier = ValueNotifier(DateTime.now());

  void _startTicker() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  // FIXED: previously this just pushed the time into `_nowNotifier` every
  // second with no setState, so the "Next prayer" card, the highlighted row
  // in the prayer list, and the countdown never advanced past whichever
  // prayer was next the last time something else happened to rebuild the
  // screen (a settings toggle, resuming the app, etc). Once every prayer
  // for that calendar day had passed, `prayerTimes!.nextPrayer()` kept
  // returning Prayer.none, the code fell back to that same stale day's
  // Fajr, and the countdown went negative instead of pointing at tomorrow.
  //
  // Now: every tick still just updates `_nowNotifier` (cheap — only the
  // clock/progress ring/countdown repaint). Only when the calendar day
  // actually changes, or the "next" prayer changes because its time just
  // passed, do we recompute and call setState — at most a handful of times
  // a day — so the rest of the screen is never more than ~1 second stale.
  void _onTick() {
    final now = DateTime.now();
    _nowNotifier.value = now;

    if (prayerTimes == null || !_cache.hasLocation) return;

    if (_prayerTimesDate != null && !_isSameDate(_prayerTimesDate!, now)) {
      // A new day started. Every static time on the current `prayerTimes`
      // object belongs to yesterday, so it must be recomputed before
      // anything (the UI or notification scheduling) reads it again.
      setState(() => _setPrayerTimes(_cache.calculatePrayerTimes()));
      _scheduleAllNotifications();
      return;
    }

    final currentNext = prayerTimes!.nextPrayer();
    if (currentNext != _lastKnownNextPrayer) {
      _lastKnownNextPrayer = currentNext;
      setState(() {}); // a prayer's time just passed — refresh the UI
    }
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Single place that sets `prayerTimes` together with the bookkeeping
  /// `_onTick` needs (the date it covers, and today's current "next"
  /// prayer). Every call site that used to assign `prayerTimes = ...`
  /// directly now goes through this instead, so none of them can update
  /// the times shown on screen without also keeping that bookkeeping in
  /// sync — which was the root cause of this bug.
  void _setPrayerTimes(PrayerTimes times) {
    prayerTimes = times;
    final now = DateTime.now();
    _prayerTimesDate = DateTime(now.year, now.month, now.day);
    _lastKnownNextPrayer = times.nextPrayer();
  }

  void _stopTicker() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    _nowNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadFromCacheOrRequest() async {
    await _cache.load();

    if (_cache.hasLocation) {
      final cachedPrayerTimes = _cache.calculatePrayerTimes();

      setState(() {
        _setPrayerTimes(cachedPrayerTimes);
        _locationName = _cache.locationName!;
        _loading = false;
      });

      _scheduleAllNotifications();
    } else {
      await _checkPermissionAndLoad();
    }
  }

  /// FIXED (bug #6): used to compute batteryOk/alarmOk and then do nothing
  /// visible with them — setState(() {}) forced a rebuild, but nothing in
  /// build() ever read the result, so a denied permission failed
  /// completely silently. Now updates the live state that
  /// _readinessBanner renders, so a real problem is always visible and
  /// actionable instead of only showing up as "azan didn't play" at the
  /// next prayer.
  Future<void> _checkSystemReadiness() async {
    final notificationOk = await Permission.notification.isGranted;
    final batteryOk = await BatteryOptimizationHelper.isWhitelisted();
    final alarmOk = await ExactAlarmPermission.isGranted();

    if (!mounted) return;

    final alarmJustGranted = _alarmOk == false && alarmOk;

    setState(() {
      _notificationOk = notificationOk;
      _batteryOk = batteryOk;
      _alarmOk = alarmOk;
    });

    // Exact-alarm permission just went from missing to granted (e.g. the
    // user fixed it from the banner or from system settings, then came
    // back) — alarms that couldn't be armed before can be now.
    if (alarmJustGranted) {
      _scheduleAllNotifications();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // The 1s timer can be throttled or paused by the OS while
        // backgrounded, so don't rely on it alone to catch a day rollover
        // that happened while the app was away — check immediately on resume.
        _onTick();
        _checkSystemReadiness();
        if (widget.isActive) _startTicker();
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // FIXED (Battery/CPU #2): the 1s ticker used to keep running for
        // the entire time the app sat backgrounded, for no visible
        // benefit — nothing driven by it is on screen. Same pattern as
        // Qibla's compass subscription: safe to stop unconditionally,
        // since the resumed case above already treats the timer as
        // unreliable while backgrounded and re-syncs from scratch anyway.
        _stopTicker();
    }
  }

  Future<void> _checkPermissionAndLoad() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _loading = false;
        _permissionError = 'Location service is disabled. Please enable GPS.';
      });
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      await _showLocationDialog();
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _loading = false;
        _permissionError =
            'Location permission is permanently denied. Please enable it from settings.';
      });
      return;
    }

    await _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loading = true;
      _permissionError = null;
    });

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      setState(() {
        _loading = false;
        _permissionError =
            'Location permission is required to calculate prayer times.';
      });
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _loading = false;
        _permissionError =
            'Location permission is permanently denied. Please enable it from settings.';
      });
      return;
    }

    try {
      // FIXED (bug #4): this used to reimplement fetch + geocode + save +
      // compute inline (a third copy of that logic, alongside QiblaScreen's
      // two). Now goes through the same LocationService every location
      // refresh in the app uses, so there's one save and one schedule.
      final result = await LocationService.refresh();

      if (!mounted) return;

      setState(() {
        _setPrayerTimes(result.prayerTimes);
        _locationName = result.locationName;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _permissionError = 'Unable to get your location. Please try again.';
      });
    }
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;
    HapticFeedback.lightImpact();

    setState(() {
      _loading = true;
      _permissionError = null;
    });

    try {
      // FIXED (bug #4): this used to update local UI state and reschedule
      // notifications but never call PrayerCache.save() — the new location
      // only ever lived in this screen's own state and reverted on the
      // next automatic reschedule or app restart. LocationService.refresh()
      // saves, recomputes, and reschedules in one place.
      final result = await LocationService.refresh();

      if (!mounted) return;

      setState(() {
        _setPrayerTimes(result.prayerTimes);
        _locationName = result.locationName;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _permissionError = 'Unable to get your location. Please try again.';
      });
    }
  }

  Future<void> _showLocationDialog() async {
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enable Location'),
        content: const Text(
          'Your location is required to calculate accurate prayer times.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    if (allow == true) {
      await _loadLocation();
      return;
    }

    await _cache.load();

    if (_cache.hasLocation) {
      final cachedPrayerTimes = _cache.calculatePrayerTimes();

      setState(() {
        _setPrayerTimes(cachedPrayerTimes);
        _locationName = _cache.locationName!;
        _loading = false;
        _permissionError = null;
      });

      _scheduleAllNotifications();
    } else {
      setState(() {
        _loading = false;
        _permissionError =
            'Location permission is required to calculate prayer times.';
      });
    }
  }

  Future<void> _scheduleAllNotifications() async {
    if (prayerTimes == null) return;
    await NotificationService.rescheduleAllForToday(prayerTimes!);
  }

  /// Shown when the user turns azan back on for a prayer whose time already
  /// passed today, so the toggle flipping with no audible/scheduled effect
  /// doesn't look broken.
  void _notifyAppliesFromTomorrow(String prayerKey) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "${_prettyName(prayerKey)}'s azan already passed for today — "
          'this will start from its next occurrence.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _useCachedLocation() async {
    await _cache.load();

    if (!_cache.hasLocation) return;

    final cachedPrayerTimes = _cache.calculatePrayerTimes();

    setState(() {
      _setPrayerTimes(cachedPrayerTimes);
      _locationName = _cache.locationName!;
      _permissionError = null;
      _loading = false;
    });

    _scheduleAllNotifications();
  }

  // ----------------------------------------------------------
  // UI
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryGreen, secondaryGreen],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.mosque, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: primaryGreen),
              const SizedBox(height: 12),
              Text(
                'Finding prayer times…',
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_permissionError != null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 16),
                  child: child,
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_off_rounded,
                        size: 48,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Location Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _permissionError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.7,
                        ),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loadLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryGreen,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Retry',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        if (_cache.hasLocation) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: _useCachedLocation,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                side: BorderSide(color: Colors.green.shade600),
                              ),
                              child: const Text(
                                'Use previous location',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final hijri = HijriCalendar.now();
    final eidName = SpecialDayHelper.eidNameFor(DateTime.now());
    final (nextPrayer, nextTime) = _resolveNextPrayer();
    final previousTime = _getPreviousPrayerTime(nextPrayer, nextTime);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _header(hijri, theme),
            if (eidName != null) _eidBanner(eidName),
            _readinessBanner(theme),
            const SizedBox(height: 16),
            _clockCard(), // UNCHANGED — left exactly as-is per request
            const SizedBox(height: 16),
            _upcomingPrayer(nextPrayer, nextTime, previousTime),
            const SizedBox(height: 8),
            Expanded(child: _prayerList(theme, isDark)),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) =>
      '${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  String _prettyName(String name) {
    return SpecialDayHelper.prettyPrayerName(name, DateTime.now());
  }

  double _getVolume(Map<String, dynamic> setting) {
    final v = setting['volume'];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return 1.0;
  }

  /// Resolves "next prayer" + its time from `prayerTimes`, mapping adhan's
  /// non-prayer markers to whichever of the 5 prayers this app actually
  /// lists comes next, and rolling over to tomorrow's Fajr (recomputed
  /// fresh from the cached location, not approximated by adding a day)
  /// when every one of today's prayers has passed.
  ///
  /// FIXED (polish #1): previously duplicated independently in build()
  /// and _prayerList(), and *neither* copy handled Prayer.sunrise — only
  /// Prayer.none (after Isha). adhan's nextPrayer() returns Prayer.sunrise
  /// during the Fajr-to-sunrise window; since 'sunrise' isn't one of this
  /// app's 5 listed prayers, _getPreviousPrayerTime's order.indexOf
  /// returned -1 and silently fell back to measuring progress from the
  /// *previous day's Isha* instead of today's Fajr — the progress ring
  /// looked stuck near empty — and no prayer-list row matched to
  /// highlight at all, since nothing in the list is named 'sunrise'.
  (Prayer, DateTime) _resolveNextPrayer() {
    final now = DateTime.now();
    final raw = prayerTimes!.nextPrayer();

    Prayer next = switch (raw) {
      Prayer.none => Prayer.fajr,
      Prayer.sunrise => Prayer.dhuhr,
      _ => raw,
    };

    DateTime time = prayerTimes!.timeForPrayer(next)!;
    if (time.isBefore(now)) {
      // Only reachable when `next` ended up Prayer.fajr — today's Fajr
      // can't simultaneously be "next" and already in the past otherwise.
      next = Prayer.fajr;
      time = _cache
          .calculatePrayerTimesFor(now.add(const Duration(days: 1)))
          .fajr;
    }

    return (next, time);
  }

  DateTime _getPreviousPrayerTime(Prayer next, DateTime nextTime) {
    const order = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    final nextName = next.name.toLowerCase();
    final idx = order.indexOf(nextName);
    final safeIdx = idx == -1 ? 0 : idx;
    final prevName = order[(safeIdx - 1 + order.length) % order.length];

    final isWrap = nextName == 'fajr';
    final targetDate = isWrap
        ? DateTime(
            nextTime.year,
            nextTime.month,
            nextTime.day,
          ).subtract(const Duration(days: 1))
        : DateTime(nextTime.year, nextTime.month, nextTime.day);

    // FIXED (polish #1, cleanup): was its own inline
    // CalculationMethod/Coordinates/PrayerTimes construction — now shares
    // PrayerCache's single implementation (see bug #4) instead of being
    // yet another copy of the same MWL+Shafi configuration to keep in sync.
    final pt = _cache.calculatePrayerTimesFor(targetDate);

    switch (prevName) {
      case 'fajr':
        return pt.fajr;
      case 'dhuhr':
        return pt.dhuhr;
      case 'asr':
        return pt.asr;
      case 'maghrib':
        return pt.maghrib;
      case 'isha':
        return pt.isha;
      default:
        return pt.fajr;
    }
  }

  // ---------------- HEADER ----------------

  Widget _header(HijriCalendar hijri, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _refreshLocation,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: primaryGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _locationName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        Text(
                          'Tap to refresh',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          const ThemeCycleButton(), // ADD: single tap-to-cycle icon
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${hijri.hDay} ${hijri.longMonthName} ${hijri.hYear} AH',
                style: const TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DateFormat('EEEE d MMM y').format(DateTime.now()),
                style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- CLOCK CARD ----------------
  // NOTE: left fully untouched per request — no theme changes here.
  Widget _clockCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Image.asset(
              'assets/images/mosque.png',
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Center(
                child: ValueListenableBuilder<DateTime>(
                  valueListenable: _nowNotifier,
                  builder: (context, now, _) => Text(
                    DateFormat('HH:mm').format(now),
                    style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- UPCOMING PRAYER ----------------

  Widget _upcomingPrayer(
    Prayer nextPrayer,
    DateTime time,
    DateTime previousTime,
  ) {
    final totalWindow = time.difference(previousTime).inSeconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade600, Colors.green.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ValueListenableBuilder<DateTime>(
          valueListenable: _nowNotifier,
          builder: (context, now, _) {
            final elapsed = now.difference(previousTime).inSeconds;
            final progress = totalWindow > 0
                ? (elapsed / totalWindow).clamp(0.0, 1.0)
                : 0.0;
            // Safety net: `_onTick` now keeps `time` from going stale, but
            // clamp anyway so a boundary tick can never show a negative
            // countdown like "-1:23:45" for the split second before the
            // next rebuild picks up the new prayer.
            final rawRemaining = time.difference(now);
            final remaining = rawRemaining.isNegative
                ? Duration.zero
                : rawRemaining;

            return Row(
              children: [
                SizedBox(
                  width: 46,
                  height: 46,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // FIXED (Battery/CPU #2): was a TweenAnimationBuilder
                      // re-animating from the old progress value to the new
                      // one over 600ms on every single tick from
                      // _nowNotifier (once a second, forever, whenever this
                      // card is visible). progress only moves by a tiny
                      // amount each tick, so the animation bought no real
                      // smoothness while keeping its own animation
                      // controller — and the repaints that come with it —
                      // active roughly 60% of every second. progress is
                      // already a continuously-advancing fraction of
                      // elapsed real time, so binding it directly looks
                      // just as smooth without the repeated restarts.
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                      const Icon(
                        Icons.timer_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next: ${_prettyName(nextPrayer.name)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'At ${DateFormat('hh:mm a').format(time)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDuration(remaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------- PRAYER LIST ----------------

  Widget _prayerList(ThemeData theme, bool isDark) {
    final prayers = {
      'fajr': prayerTimes!.fajr,
      'dhuhr': prayerTimes!.dhuhr,
      'asr': prayerTimes!.asr,
      'maghrib': prayerTimes!.maghrib,
      'isha': prayerTimes!.isha,
    };

    // FIXED (polish #1): this used to be its own independent copy of the
    // next-prayer resolution, with the same missing Prayer.sunrise
    // handling as build()'s copy — see _resolveNextPrayer for the full
    // explanation. Both now share one implementation.
    final (next, nextTime) = _resolveNextPrayer();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(35),
          topRight: Radius.circular(35),
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          itemCount: prayers.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: isDark
                ? Colors.white.withOpacity(0.06)
                : const Color(0xFFF0F0F0),
          ),
          itemBuilder: (context, index) {
            final prayerKey = prayers.keys.elementAt(index);
            final prayerTime = prayers.values.elementAt(index);
            final setting = NotificationService.prayerSettings[prayerKey]!;

            final isNext = next.name.toLowerCase() == prayerKey;
            // NOTE: the per-row alarm id is no longer needed here directly —
            // NotificationService.applyAzanSettingForPrayer (bug #3) now
            // owns id assignment across today + the lookahead days.

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isNext
                    ? primaryGreen.withOpacity(isDark ? 0.1 : 0.045)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: isNext
                              ? Colors.green.shade700
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _prettyName(prayerKey),
                              style: TextStyle(
                                fontWeight: isNext
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 17,
                                color: isNext
                                    ? Colors.green.shade700
                                    : theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('hh:mm a').format(prayerTime),
                              style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.5),
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 116,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                activeTrackColor: const Color(0xFF6EC6FF),
                                inactiveTrackColor: const Color(
                                  0xFF6EC6FF,
                                ).withOpacity(0.3),
                                thumbColor: const Color(0xFF6EC6FF),
                                overlayColor: const Color(
                                  0xFF6EC6FF,
                                ).withOpacity(0.2),
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 12,
                                ),
                              ),
                              child: Slider(
                                value: _getVolume(setting),
                                min: 0.0,
                                max: 1.0,
                                divisions: 10,
                                label:
                                    '${((_getVolume(setting)) * 100).round()}%',
                                onChanged: (v) {
                                  setState(() => setting['volume'] = v);
                                },
                                onChangeEnd: (v) async {
                                  await NotificationService.saveSettings();
                                  // FIXED (bug #2): previously scheduled
                                  // unconditionally, and AlarmManager fires
                                  // an exact alarm set for a past time
                                  // almost immediately — nudging the volume
                                  // for a prayer that already happened
                                  // today used to play the azan right now.
                                  //
                                  // FIXED (bug #3): now goes through
                                  // applyAzanSettingForPrayer, which reads
                                  // the volume we just saved and re-applies
                                  // it across today *and* the pre-armed
                                  // lookahead days — not just today — while
                                  // still skipping any day whose time has
                                  // already passed.
                                  await NotificationService.applyAzanSettingForPrayer(
                                    prayerKey,
                                    prayerTime,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      _actionIcon(
                        icon: setting['reminder'] == true
                            ? Icons.alarm_on
                            : Icons.alarm_off,
                        activeColor: Colors.green,
                        isActive: setting['reminder'] == true,
                        isDark: isDark,
                        semanticLabel: setting['reminder'] == true
                            ? 'Reminder on for ${_prettyName(prayerKey)}. Double tap to turn off.'
                            : 'Reminder off for ${_prettyName(prayerKey)}. Double tap to turn on.',
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          setState(
                            () => setting['reminder'] = !setting['reminder'],
                          );
                          await NotificationService.saveSettings();
                          _scheduleAllNotifications();
                        },
                        onLongPress: () async {
                          HapticFeedback.heavyImpact();
                          // FIXED (bug #11): same unsafe cast as
                          // NotificationService.rescheduleAllForToday —
                          // this would throw and drop the long-press
                          // entirely if minutesBefore was ever a double.
                          final minutes = await _showDurationPickerDialog(
                            (setting['minutesBefore'] as num?)?.toInt() ?? 10,
                          );
                          if (minutes != null) {
                            setState(() {
                              setting['minutesBefore'] = minutes;
                              setting['reminder'] = true;
                            });
                            await NotificationService.saveSettings();
                            _scheduleAllNotifications();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _actionIcon(
                        icon: setting['azan'] == true
                            ? Icons.mosque
                            : Icons.mosque_outlined,
                        activeColor: Colors.blue,
                        isActive: setting['azan'] == true,
                        isDark: isDark,
                        semanticLabel: setting['azan'] == true
                            ? 'Azan sound on for ${_prettyName(prayerKey)}. Double tap to turn off.'
                            : 'Azan sound off for ${_prettyName(prayerKey)}. Double tap to turn on.',
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          setState(() => setting['azan'] = !setting['azan']);
                          await NotificationService.saveSettings();

                          // FIXED (bug #2 + bug #3): applyAzanSettingForPrayer
                          // handles both directions correctly now. Turning
                          // azan off cancels it across *every* pre-armed
                          // lookahead day, not just today (previously only
                          // today's alarm was cancelled, so a prayer turned
                          // off could still ring on a day already armed in
                          // advance). Turning it on re-arms today (skipped
                          // if today's time already passed, avoiding the
                          // instant-fire bug) plus every lookahead day —
                          // so it no longer depends on the midnight job to
                          // pick tomorrow back up.
                          await NotificationService.applyAzanSettingForPrayer(
                            prayerKey,
                            prayerTime,
                          );

                          if (setting['azan'] == true &&
                              !prayerTime.isAfter(DateTime.now())) {
                            _notifyAppliesFromTomorrow(prayerKey);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _eidBanner(String eidName) {
    final estimate = SpecialDayHelper.estimatedEidTime(
      prayerTimes!,
      offsetMinutes: NotificationService.eidOffsetMinutes,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE9A319), Color(0xFFF4C542)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE9A319).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.celebration_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$eidName Mubarak!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              // CHANGED: was a bare GestureDetector around an icon with no
              // accessible name — a screen reader announced nothing tappable here.
              IconAction(
                label: 'Adjust Eid prayer time offset',
                onTap: () => _showEidOffsetPicker(context),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Estimated prayer time: ${DateFormat('hh:mm a').format(estimate)} (sunrise + ${NotificationService.eidOffsetMinutes} min)',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'This is an estimate, not official — confirm with your local mosque.',
            style: TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }

  /// FIXED (bug #6): _checkSystemReadiness used to compute permission
  /// status and then show nothing — the old _batterySnackShown/
  /// _alarmSnackShown flags were the entire remnant of a snackbar that
  /// never got built. This renders a persistent card instead, driven by
  /// that same live state, with a "Fix" action per missing permission
  /// (a deliberate tap — never an automatic re-prompt, see initState)
  /// and a "Test azan" button so the user can actually confirm sound
  /// works after fixing something instead of finding out at the next
  /// prayer. This also covers the restored-device case: if a backup
  /// restored `onboarding completed` but Android reset the underlying
  /// permissions (as it always does for exact alarms on Android 14+),
  /// onboarding gets skipped, but this banner still catches it here.
  Widget _readinessBanner(ThemeData theme) {
    final issues = <_ReadinessIssue>[
      if (_notificationOk == false)
        _ReadinessIssue(
          "Notifications are off — prayer reminders won't show.",
          () async => Permission.notification.request(),
        ),
      if (_batteryOk == false)
        _ReadinessIssue(
          'Battery optimization may delay or block the Azan.',
          BatteryOptimizationHelper.requestDisable,
        ),
      if (_alarmOk == false)
        _ReadinessIssue(
          'Exact alarms are off — the Azan may not play on time.',
          ExactAlarmPermission.ensureEnabled,
        ),
    ];

    if (issues.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(
          theme.brightness == Brightness.dark ? 0.18 : 0.08,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Azan may not sound',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final issue in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      issue.message,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.75,
                        ),
                        height: 1.3,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await issue.fix();
                      await _checkSystemReadiness();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Fix',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => NotificationService.testAzan(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Test azan',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEidOffsetPicker(BuildContext context) async {
    int tempValue = NotificationService.eidOffsetMinutes;
    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Eid Time Offset'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Minutes after sunrise your local mosque typically holds Eid prayer.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              Slider(
                value: tempValue.toDouble(),
                min: 0,
                max: 60,
                divisions: 12,
                label: '$tempValue min',
                activeColor: primaryGreen,
                onChanged: (v) => setDialogState(() => tempValue = v.round()),
              ),
              Text(
                '$tempValue minutes',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, tempValue),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      await NotificationService.saveEidOffset(result);
      setState(() {});
    }
  }

  Widget _actionIcon({
    required IconData icon,
    required Color activeColor,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
    required String semanticLabel,
    VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withOpacity(0.12)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Icon(
            icon,
            key: ValueKey(icon),
            size: 20,
            color: isActive ? activeColor : Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  Future<int?> _showDurationPickerDialog(int currentMinutes) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _DurationPickerSheet(initialMinutes: currentMinutes),
    );
  }
}

class _DurationPickerSheet extends StatefulWidget {
  final int initialMinutes;

  const _DurationPickerSheet({required this.initialMinutes});

  @override
  State<_DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<_DurationPickerSheet> {
  static const int _loopCount = 10000;

  late FixedExtentScrollController _hoursCtrl;
  late FixedExtentScrollController _minutesCtrl;

  int hours = 0;
  int minutes = 0;

  int _centerIndex(int value, int max) {
    final base = (_loopCount ~/ 2);
    return base - (base % max) + value;
  }

  @override
  void initState() {
    super.initState();

    hours = widget.initialMinutes ~/ 60;
    minutes = widget.initialMinutes % 60;
    hours = hours.clamp(0, 23);
    minutes = minutes.clamp(0, 59);

    _hoursCtrl = FixedExtentScrollController(
      initialItem: _centerIndex(hours, 24),
    );
    _minutesCtrl = FixedExtentScrollController(
      initialItem: _centerIndex(minutes, 60),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Reminder Before Prayer',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _wheel(
                    label: 'Hours',
                    controller: _hoursCtrl,
                    max: 24,
                    onChanged: (v) => setState(() => hours = v),
                  ),
                  _wheel(
                    label: 'Minutes',
                    controller: _minutesCtrl,
                    max: 60,
                    onChanged: (v) => setState(() => minutes = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: () => Navigator.pop(context, hours * 60 + minutes),
              child: const Text(
                'SET REMINDER',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wheel({
    required String label,
    required FixedExtentScrollController controller,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: CupertinoPicker.builder(
              scrollController: controller,
              itemExtent: 52,
              backgroundColor: Colors.black,
              onSelectedItemChanged: (index) => onChanged(index % max),
              itemBuilder: (_, index) {
                final value = index % max;
                return Center(
                  child: Text(
                    value.toString().padLeft(2, '0'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationPermission {
  static Future<void> request() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }
}

/// One missing permission shown in the readiness banner (bug #6): a short
/// user-facing message and the action a tap on "Fix" runs.
class _ReadinessIssue {
  final String message;
  final Future<void> Function() fix;
  const _ReadinessIssue(this.message, this.fix);
}

/// Single icon button that cycles Light -> Dark -> Auto on each tap,
/// instead of a three-way selector row.
class ThemeCycleButton extends StatefulWidget {
  const ThemeCycleButton({super.key});

  @override
  State<ThemeCycleButton> createState() => _ThemeCycleButtonState();
}

class _ThemeCycleButtonState extends State<ThemeCycleButton> {
  final ThemeController _controller = ThemeController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  void _cycle() {
    HapticFeedback.selectionClick();
    final next = switch (_controller.mode) {
      AppThemeMode.light => AppThemeMode.dark,
      AppThemeMode.dark => AppThemeMode.system,
      AppThemeMode.system => AppThemeMode.light,
    };
    _controller.setMode(next);
  }

  IconData get _icon => switch (_controller.mode) {
    AppThemeMode.light => Icons.light_mode_rounded,
    AppThemeMode.dark => Icons.dark_mode_rounded,
    AppThemeMode.system => Icons.brightness_auto_rounded,
  };

  String get _tooltip => switch (_controller.mode) {
    AppThemeMode.light => 'Light mode — tap for Dark',
    AppThemeMode.dark => 'Dark mode — tap for Auto',
    AppThemeMode.system => 'Auto mode — tap for Light',
  };

  // In _ThemeCycleButtonState.build() — replace the outer GestureDetector+Tooltip
  @override
  Widget build(BuildContext context) {
    return IconAction(
      label:
          _tooltip, // reuse the existing getter — was already a good description
      onTap: _cycle,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1FA45B).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: RotationTransition(turns: anim, child: child),
          ),
          child: Icon(
            _icon,
            key: ValueKey(_icon),
            color: const Color(0xFF1FA45B),
            size: 18,
          ),
        ),
      ),
    );
  }
}
