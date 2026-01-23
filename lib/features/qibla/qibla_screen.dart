import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/qibla_utils.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double? _qiblaDirection;
  double _heading = 0;

  bool _permissionGranted = false;
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
        _permissionGranted = false;
        _loading = false;
        _errorMessage =
            'Location permission is required to calculate Qibla direction.';
      });
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _permissionGranted = false;
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
          _permissionGranted = true;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Qibla Direction')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    await Geolocator.openAppSettings();
                  },
                  child: const Text('Open Settings'),
                ),
                TextButton(
                  onPressed: _loadLocation,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
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
        /// Compass Card
        Container(
          width: 280,
          height: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                blurRadius: 20,
                offset: Offset(0, 8),
                color: Colors.black12,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              /// Compass Ring
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.shade200, width: 6),
                ),
              ),

              /// Needle
              AnimatedRotation(
                turns: angle / (2 * pi),
                duration: const Duration(milliseconds: 300),
                child: Column(
                  children: const [
                    Icon(Icons.navigation, size: 90, color: Colors.green),
                    SizedBox(height: 6),
                  ],
                ),
              ),

              /// Center Dot
              Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        /// 🎯 Status
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: aligned ? Colors.green : Colors.orange,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            aligned ? 'Aligned with Qibla 🤲' : '$difference° to Qibla',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 12),

        const Text(
          'Rotate your phone to align the arrow with Qibla',
          style: TextStyle(color: Colors.black54),
        ),
      ],
    );
  }
}
