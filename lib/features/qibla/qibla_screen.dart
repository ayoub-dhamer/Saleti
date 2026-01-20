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

  @override
  void initState() {
    super.initState();
    _loadLocation();
    FlutterCompass.events?.listen((event) {
      if (!mounted) return;
      setState(() => _heading = event.heading ?? 0);
    });
  }

  Future<void> _loadLocation() async {
    await Geolocator.requestPermission();
    final pos = await Geolocator.getCurrentPosition();

    final qibla = calculateQiblaDirection(pos.latitude, pos.longitude);

    if (mounted) {
      setState(() => _qiblaDirection = qibla);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_qiblaDirection == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final angle = ((_qiblaDirection! - _heading) * pi / 180);
    final difference = ((_qiblaDirection! - _heading + 360) % 360).round();

    final isAligned = difference < 5 || difference > 355;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
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
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1FA45B), Color(0xFF4FC3A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          /// 🔝 Top Row
          Row(
            children: [
              /// 🔙 Back
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),

              const Spacer(),

              /// 🧭 Title
              const Text(
                'Qibla Direction',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const Spacer(),
              const SizedBox(width: 24),
            ],
          ),

          const SizedBox(height: 10),

          /// 📝 Subtitle
          const Text(
            'Align your phone to face the Kaaba',
            style: TextStyle(color: Colors.white70, fontSize: 13),
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
