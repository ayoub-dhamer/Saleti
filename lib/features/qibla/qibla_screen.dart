import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:saleti/utils/prayer_cache.dart';
import 'package:saleti/widgets/icon_action.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QiblaScreen extends StatefulWidget {
  final bool isActive;

  const QiblaScreen({super.key, this.isActive = true});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double? _qiblaDirection;
  double _heading = 0;

  bool _loading = true;
  String? _errorMessage;

  bool _wasAligned = false;
  bool _showCalibrationHint = false;

  static const String _calibrationHintKey = 'qibla_calibration_hint_dismissed';

  StreamSubscription<CompassEvent>? _compassSub;

  final PrayerCache _cache = PrayerCache();

  static const Color primaryGreen = Color(0xFF1FA45B);
  static const Color secondaryGreen = Color(0xFF4FC3A1);

  @override
  void initState() {
    super.initState();
    _loadCalibrationHintState();
    _loadFromCacheOrRequest();
    if (widget.isActive) _startCompass();
  }

  Future<void> _loadFromCacheOrRequest() async {
    await _cache.load();

    if (_cache.hasLocation) {
      final qibla = calculateQiblaDirection(_cache.lat!, _cache.lng!);
      if (mounted) {
        setState(() {
          _qiblaDirection = qibla;
          _loading = false;
        });
      }
    } else {
      await _checkPermissionAndLoad();
    }
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;
    HapticFeedback.lightImpact();

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final qibla = calculateQiblaDirection(pos.latitude, pos.longitude);

      await _cache.save(
        lat: pos.latitude,
        lng: pos.longitude,
        locationName: _cache.locationName ?? 'Unknown Location',
      );

      if (!mounted) return;
      setState(() {
        _qiblaDirection = qibla;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to get your location. Please try again.';
      });
    }
  }

  Future<void> _loadCalibrationHintState() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_calibrationHintKey) ?? false;
    if (mounted) {
      setState(() => _showCalibrationHint = !dismissed);
    }
  }

  Future<void> _dismissCalibrationHint() async {
    setState(() => _showCalibrationHint = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_calibrationHintKey, true);
  }

  @override
  void didUpdateWidget(covariant QiblaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startCompass();
    } else if (!widget.isActive && oldWidget.isActive) {
      _stopCompass();
    }
  }

  void _startCompass() {
    _compassSub ??= FlutterCompass.events?.listen((event) {
      if (!mounted) return;
      setState(() => _heading = event.heading ?? 0);
    });
  }

  void _stopCompass() {
    _compassSub?.cancel();
    _compassSub = null;
  }

  @override
  void dispose() {
    _stopCompass();
    super.dispose();
  }

  Future<void> _checkPermissionAndLoad() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _loading = false;
        _errorMessage = 'Location service is disabled. Please enable GPS.';
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
        _errorMessage =
            'Location permission is permanently denied. Please enable it from settings.';
      });
      return;
    }

    await _loadLocation();
  }

  Future<void> _showLocationDialog() async {
    final theme = Theme.of(context);
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Enable Location',
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
          ),
          content: Text(
            'We need your location to calculate the Qibla direction accurately.',
            style: TextStyle(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryGreen),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Enable',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (allow == true) {
      await _loadLocation();
    } else {
      setState(() {
        _loading = false;
        _errorMessage =
            'Location permission is required to show Qibla direction.';
      });
    }
  }

  Future<void> _loadLocation() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      setState(() {
        _loading = false;
        _errorMessage =
            'Location permission is required to calculate Qibla direction.';
      });
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _loading = false;
        _errorMessage =
            'Location permission is permanently denied. Please enable it from settings.';
      });
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition();
      final qibla = calculateQiblaDirection(pos.latitude, pos.longitude);

      await _cache.save(
        lat: pos.latitude,
        lng: pos.longitude,
        locationName: _cache.locationName ?? 'Unknown Location',
      );

      if (mounted) {
        setState(() {
          _qiblaDirection = qibla;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Unable to get your location. Please try again.';
      });
    }
  }

  // ---------------- LOADING / ERROR STATES ----------------

  Widget _loadingView(ThemeData theme) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // CHANGED
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
              child: const Icon(Icons.explore, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: primaryGreen),
            const SizedBox(height: 12),
            Text(
              'Finding the Qibla…',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                fontSize: 13,
              ), // CHANGED
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView({
    required IconData icon,
    required String title,
    required String message,
    required VoidCallback onRetry,
    String retryText = 'Try Again',
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // CHANGED
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
                color: theme.cardColor, // CHANGED
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ), // CHANGED
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 48, color: Colors.orange),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ), // CHANGED
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.7,
                      ),
                      height: 1.4,
                    ), // CHANGED
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        retryText,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_loading) {
      return _loadingView(theme);
    }

    if (_errorMessage != null) {
      final gpsDisabled = _errorMessage!.toLowerCase().contains('gps');

      return _errorView(
        icon: gpsDisabled ? Icons.gps_off : Icons.location_disabled,
        title: gpsDisabled
            ? "GPS is turned off"
            : "Location permission required",
        message: _errorMessage!,
        onRetry: _loadLocation,
        retryText: "Try Again",
      );
    }

    final angle = ((_qiblaDirection! - _heading) * pi / 180);
    final difference = ((_qiblaDirection! - _heading + 360) % 360).round();
    final isAligned = difference < 5 || difference > 355;

    if (isAligned && !_wasAligned) {
      HapticFeedback.mediumImpact();
    }
    _wasAligned = isAligned;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // CHANGED
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, secondaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Qibla Direction',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          _header(),
          if (_showCalibrationHint) _calibrationHint(isDark),
          Expanded(
            child: Center(
              child: Semantics(
                liveRegion: true, // announces changes without needing re-focus
                label: isAligned
                    ? 'Facing the Qibla'
                    : '$difference degrees off — turn ${difference > 180 ? "left" : "right"} to align',
                child: _compass(angle, difference, isAligned, theme, isDark),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🌿 Header — unchanged, brand gradient regardless of theme
  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [primaryGreen, secondaryGreen]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find the Qibla',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Align your phone to face the Kaaba',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconAction(
            label: 'Refresh location',
            onTap: _refreshLocation,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30),
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🧭 Calibration hint banner
  Widget _calibrationHint(bool isDark) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(isDark ? 0.18 : 0.12), // CHANGED
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.amber, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'If the reading seems off, move your phone in a figure-8 to calibrate the compass.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.white.withOpacity(0.85)
                      : Colors.black87,
                ), // CHANGED
              ),
            ),
            IconAction(
              label: 'Dismiss calibration tip',
              onTap: _dismissCalibrationHint,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🧭 Compass Widget
  Widget _compass(
    double angle,
    int difference,
    bool aligned,
    ThemeData theme,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            /// 1. Outer glow — pulses when aligned
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: aligned ? 320 : 300,
              height: aligned ? 320 : 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: aligned
                        ? Colors.green.withOpacity(0.25)
                        : Colors.black.withOpacity(
                            isDark ? 0.15 : 0.05,
                          ), // CHANGED
                    blurRadius: aligned ? 40 : 30,
                    spreadRadius: aligned ? 8 : 5,
                  ),
                ],
              ),
            ),

            /// 2. Main compass plate
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: theme.cardColor, // CHANGED: was Colors.white
                shape: BoxShape.circle,
                border: Border.all(
                  color: aligned
                      ? Colors.green.shade400
                      : (isDark
                            ? Colors.white24
                            : Colors.grey.shade200), // CHANGED
                  width: aligned ? 2.5 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ), // CHANGED
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  /// 3. Static degree markers
                  ...List.generate(36, (index) {
                    final isMajor = index % 9 == 0;
                    return Transform.rotate(
                      angle: (index * 10) * pi / 180,
                      child: VerticalDivider(
                        color: isMajor
                            ? (aligned
                                  ? Colors.green.shade400
                                  : Colors.green.shade300)
                            : (isDark
                                  ? Colors.white24
                                  : Colors.grey.shade300), // CHANGED
                        thickness: isMajor ? 3 : 1,
                        indent: 0,
                        endIndent: 260,
                      ),
                    );
                  }),

                  /// 4. Cardinal directions
                  const Positioned(
                    top: 15,
                    child: Text(
                      'N',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 15,
                    child: Text(
                      'S',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ), // CHANGED
                  ),
                  Positioned(
                    right: 15,
                    child: Text(
                      'E',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ), // CHANGED
                  ),
                  Positioned(
                    left: 15,
                    child: Text(
                      'W',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ), // CHANGED
                  ),
                ],
              ),
            ),

            /// 5. Rotating needle layer
            AnimatedRotation(
              turns: angle / (2 * pi),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 0,
                      child: Column(
                        children: [
                          AnimatedScale(
                            duration: const Duration(milliseconds: 300),
                            scale: aligned ? 1.15 : 1.0,
                            child: Icon(
                              Icons.mosque,
                              size: 34,
                              color: aligned
                                  ? Colors.green
                                  : theme.textTheme.bodyLarge?.color, // CHANGED
                            ),
                          ),
                          Container(
                            width: 4,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  aligned
                                      ? Colors.green
                                      : (theme.textTheme.bodyLarge?.color ??
                                            Colors.black87), // CHANGED
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// 6. Center hub
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: theme.cardColor, // CHANGED: was Colors.white
                shape: BoxShape.circle,
                border: Border.all(
                  color: aligned
                      ? Colors.green.shade300
                      : (isDark
                            ? Colors.white24
                            : Colors.grey.shade300), // CHANGED
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ), // CHANGED
                ],
              ),
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: aligned ? 10 : 8,
                  height: aligned ? 10 : 8,
                  decoration: BoxDecoration(
                    color: aligned
                        ? Colors.green
                        : (theme.textTheme.bodyLarge?.color ??
                              Colors.black), // CHANGED
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 40),

        /// 🎯 Digital readout card
        _buildStatusCard(difference, aligned, theme, isDark),

        const SizedBox(height: 16),

        Text(
          'Ensure phone is on a flat surface',
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(
              0.6,
            ), // CHANGED
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    int difference,
    bool aligned,
    ThemeData theme,
    bool isDark,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
      decoration: BoxDecoration(
        gradient: aligned
            ? const LinearGradient(colors: [primaryGreen, secondaryGreen])
            : null,
        color: aligned ? null : theme.cardColor, // CHANGED: was Colors.white
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: aligned
                ? Colors.green.withOpacity(0.35)
                : Colors.black.withOpacity(isDark ? 0.3 : 0.05), // CHANGED
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(scale: anim, child: child),
        ),
        child: Row(
          key: ValueKey(aligned),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              aligned ? Icons.check_circle : Icons.explore_outlined,
              color: aligned ? Colors.white : Colors.orange,
            ),
            const SizedBox(width: 12),
            Text(
              aligned ? 'Facing Qibla' : '$difference° Off Track',
              style: TextStyle(
                color: aligned
                    ? Colors.white
                    : theme.textTheme.bodyLarge?.color, // CHANGED
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double calculateQiblaDirection(double lat, double lon) {
  const kaabaLat = 21.4225;
  const kaabaLon = 39.8262;

  final phiK = kaabaLat * pi / 180.0;
  final lambdaK = kaabaLon * pi / 180.0;
  final phi = lat * pi / 180.0;
  final lambda = lon * pi / 180.0;

  final y = sin(lambdaK - lambda);
  final x = cos(phi) * tan(phiK) - sin(phi) * cos(lambdaK - lambda);

  final bearing = atan2(y, x) * 180 / pi;
  return (bearing + 360) % 360;
}
