import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/battery_optimization_helper.dart';
import '../../utils/exact_alarm_permission.dart';
import '../../utils/onboarding_helper.dart';
import '../home/home_screen.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  State<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends State<PermissionOnboardingScreen> {
  late final PageController _controller;
  int _currentStep = 0;

  final List<_OnboardingStep> _steps = [];

  @override
  void initState() {
    super.initState();
    _controller = PageController();

    _steps.addAll([
      _OnboardingStep(
        title: 'Enable Location',
        description:
            'Your location is required to calculate accurate prayer times.',
        requestPermission: _requestLocation,
      ),
      _OnboardingStep(
        title: 'Enable Notifications',
        description:
            'We need permission to send prayer reminders and Azan alerts.',
        requestPermission: _requestNotification,
      ),
      _OnboardingStep(
        title: 'Disable Battery Optimization',
        description:
            'This ensures Azan plays on time even when your phone is locked.',
        requestPermission: _requestBatteryOptimization,
      ),
      _OnboardingStep(
        title: 'Allow Exact Alarm',
        description:
            'This is required for precise prayer notifications on Android.',
        requestPermission: _requestExactAlarm,
      ),
    ]);

    _skipGrantedSteps();
  }

  /// Skip steps that are already granted
  Future<void> _skipGrantedSteps() async {
    for (int i = 0; i < _steps.length; i++) {
      final granted = await _steps[i].isAlreadyGranted();
      if (granted) _currentStep++;
    }
    if (_currentStep > 0) _controller.jumpToPage(_currentStep);
  }

  /// Move to next step after requesting permission
  Future<void> _nextStep() async {
    final granted = await _steps[_currentStep].requestPermission();

    if (!granted) return; // Mandatory: cannot proceed if denied

    int nextStep = _currentStep + 1;

    while (nextStep < _steps.length) {
      if (await _steps[nextStep].isAlreadyGranted())
        nextStep++;
      else
        break;
    }

    if (nextStep < _steps.length) {
      setState(() => _currentStep = nextStep);
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      await setOnboardingCompleted();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  // ------------------ PERMISSION HANDLERS ------------------
  Future<bool> _requestNotification() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> _requestBatteryOptimization() async {
    await BatteryOptimizationHelper.requestDisable();
    return await BatteryOptimizationHelper.isWhitelisted();
  }

  Future<bool> _requestExactAlarm() async {
    await ExactAlarmPermission.ensureEnabled(context);
    return await ExactAlarmPermission.isGranted();
  }

  Future<bool> _requestLocation() async {
    // 1️⃣ Ensure device location service is enabled
    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        // Open system location settings
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Enable GPS'),
            content: const Text(
              'Saleti needs your location. Please enable GPS in the next screen.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Geolocator.openLocationSettings(); // <-- SYSTEM SETTINGS
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
      }

      // After returning from settings, check again
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }

    // 2️⃣ Request system location permission (foreground)
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    final granted =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;

    if (!granted && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Location Required'),
          content: const Text(
            'You must allow Saleti to access your location to continue.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }

    return granted;
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                itemBuilder: (_, index) {
                  final s = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          s.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.description,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingStep {
  final String title;
  final String description;
  final Future<bool> Function() requestPermission;

  _OnboardingStep({
    required this.title,
    required this.description,
    required this.requestPermission,
  });

  Future<bool> isAlreadyGranted() async {
    if (title.contains('Location')) {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var perm = await Geolocator.checkPermission();
      return perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
    } else if (title.contains('Notification')) {
      return await Permission.notification.isGranted;
    } else if (title.contains('Battery')) {
      return await BatteryOptimizationHelper.isWhitelisted();
    } else if (title.contains('Exact Alarm')) {
      return await ExactAlarmPermission.isGranted();
    }
    return false;
  }
}
