import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double? _qiblaDirection;
  double _heading = 0;

  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndLoad();

    FlutterCompass.events?.listen((event) {
      if (!mounted) return;
      setState(() => _heading = event.heading ?? 0);
    });
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

    // ✅ Permission already granted
    await _loadLocation();
  }

  Future<void> _showLocationDialog() async {
    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enable Location'),
          content: const Text(
            'We need your location to calculate the Qibla direction accurately.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enable'),
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

  Widget _errorView({
    required IconData icon,
    required String title,
    required String message,
    required VoidCallback onRetry,
    String retryText = 'Try Again',
  }) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.05),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 72, color: Colors.orange),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FA45B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(retryText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      final gpsDisabled = _errorMessage!.toLowerCase().contains('gps');

      return _errorView(
        icon: gpsDisabled ? Icons.gps_off : Icons.location_disabled,
        title: gpsDisabled
            ? "GPS is turned off"
            : "Location permission required",
        message: _errorMessage!,
        onRetry: _loadLocation, // your function that retries fetching location
        retryText: "Try Again",
      );
    }

    final angle = ((_qiblaDirection! - _heading) * pi / 180);
    final difference = ((_qiblaDirection! - _heading + 360) % 360).round();

    final isAligned = difference < 5 || difference > 355;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1FA45B), Color(0xFF4FC3A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: const Text(
          'Qibla Direction',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _header(),
          Expanded(
            child: Center(child: _compass(angle, difference, isAligned)),
          ),
        ],
      ),
    );
  }

  /// 🌿 Header
  /// 🌿 Header
  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1FA45B), Color(0xFF4FC3A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
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
    );
  }

  /// 🧭 Compass Widget
  Widget _compass(double angle, int difference, bool aligned) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            /// 1. Outer Glow/Shadow
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: aligned
                        ? Colors.green.withOpacity(0.15)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),

            /// 2. The Main Compass Plate
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: aligned ? Colors.green.shade400 : Colors.grey.shade200,
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  /// 3. Static Degree Markers (The Dial)
                  ...List.generate(36, (index) {
                    return Transform.rotate(
                      angle: (index * 10) * pi / 180,
                      child: VerticalDivider(
                        color: index % 9 == 0
                            ? Colors.green.shade300
                            : Colors.grey.shade300,
                        thickness: index % 9 == 0 ? 3 : 1,
                        indent: 0,
                        endIndent: 260,
                      ),
                    );
                  }),

                  /// 4. Cardinal Directions
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
                  const Positioned(
                    bottom: 15,
                    child: Text(
                      'S',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Positioned(
                    right: 15,
                    child: Text(
                      'E',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Positioned(
                    left: 15,
                    child: Text(
                      'W',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            /// 5. The Rotating Needle Layer
            AnimatedRotation(
              turns: angle / (2 * pi),
              duration: const Duration(milliseconds: 400),
              curve: Curves.decelerate, // Smooth organic movement
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    /// Kaaba Icon / Pointy end
                    Positioned(
                      top: 0,
                      child: Column(
                        children: [
                          // A small Kaaba or Icon
                          Icon(
                            Icons.mosque,
                            size: 34,
                            color: aligned ? Colors.green : Colors.black87,
                          ),
                          // The Arrow Head
                          Container(
                            width: 4,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  aligned ? Colors.green : Colors.black87,
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

            /// 6. Center Hub
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: aligned ? Colors.green : Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 40),

        /// 🎯 Digital Readout Card
        _buildStatusCard(difference, aligned),

        const SizedBox(height: 16),

        const Text(
          'Ensure phone is on a flat surface',
          style: TextStyle(
            color: Colors.black38,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard(int difference, bool aligned) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: aligned ? Colors.green : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: aligned
                ? Colors.green.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
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
              color: aligned ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
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
