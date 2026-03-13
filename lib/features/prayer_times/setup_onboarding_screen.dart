import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/battery_optimization_permission.dart';
import '../../utils/exact_alarm_permission.dart';
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

      // ✅ NEW FINAL STEP
      _OnboardingStep(
        title: 'Confirm Setup',
        description: 'Everything is ready. You can start using Saleti.',
        isConfirmation: true, // ✅ dummy function for confirmation step
      ),
    ]);

    _skipGrantedSteps();
  }

  /// Skip steps that are already granted
  Future<void> _skipGrantedSteps() async {
    int stepIndex = 0;
    for (final step in _steps) {
      final granted = await step.isAlreadyGranted();
      if (granted)
        stepIndex++;
      else
        break;
    }

    // Clamp to last valid index
    _currentStep = stepIndex.clamp(0, _steps.length - 1);

    // Wait until the first frame is built before jumping
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients && _currentStep > 0) {
        _controller.jumpToPage(_currentStep);
      }
    });
  }

  Future<void> _nextStep() async {
    final current = _steps[_currentStep];

    bool granted = true;

    // Only request permission if not a confirmation step
    if (!current.isConfirmation) {
      if (current.requestPermission == null) return;
      granted = await current.requestPermission!();
    }

    if (!granted) return; // Mandatory: cannot proceed if denied

    int nextStep = _currentStep + 1;

    // Skip already granted steps
    while (nextStep < _steps.length) {
      if (await _steps[nextStep].isAlreadyGranted()) {
        nextStep++;
      } else {
        break;
      }
    }

    if (nextStep < _steps.length) {
      setState(() => _currentStep = nextStep);
      if (_controller.hasClients) {
        _controller.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // Completed all steps including confirmation
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
    // 1️⃣ Check if location service (GPS) is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    // 2️⃣ Check location permission
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // 3️⃣ Handle permanently denied
    if (permission == LocationPermission.deniedForever) {
      if (!context.mounted) return false;

      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Location access has been permanently denied. Please enable it from system settings to continue.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true), // Retry
              child: const Text('Retry'),
            ),
          ],
        ),
      );

      if (retry == true) {
        // Open app settings to reask permission
        await Geolocator.openAppSettings();
        // Then try requesting permission again recursively
        return _requestLocation();
      }

      return false;
    }

    // 4️⃣ Final granted check
    final granted =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;

    if (!granted && context.mounted) {
      // If not granted, show dialog and allow retry
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Location Required'),
          content: const Text(
            'You must allow location access to continue using Saleti.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context, false), // Cancel
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true), // Retry
              child: const Text('Retry'),
            ),
          ],
        ),
      );

      if (retry == true) {
        // Re-request permission
        return _requestLocation();
      }
    }

    return granted;
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final progress = (_currentStep + 1) / _steps.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // ───────────── Progress Bar ─────────────
            // ───────────── Animated Progress Bar ─────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(
                  begin: 0,
                  end: (_currentStep + 1) / _steps.length,
                ),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF1FA45B),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ───────────── Animated Content ─────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  final slide =
                      Tween<Offset>(
                        begin: const Offset(0.2, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: _OnboardingPage(
                  step: step,
                  isLastStep: _currentStep == _steps.length - 1,
                ),
              ),
            ),

            // ───────────── Step Indicators ─────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: _currentStep == index ? 14 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentStep >= index
                          ? const Color(0xFF1FA45B) // active step
                          : Colors.grey.shade400, // inactive step
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),

            // ───────────── Continue Button ─────────────
            // ───────────── Animated Continue Button ─────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.9,
                      end: 1.0,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: ElevatedButton(
                  key: ValueKey(_currentStep),
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: const Color(0xFF1FA45B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 3,
                  ),
                  child: Text(
                    _currentStep == _steps.length - 1
                        ? 'Confirm & Start'
                        : 'Continue',

                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: .3,
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
}

class _OnboardingStep {
  final String title;
  final String description;
  final Future<bool> Function()? requestPermission;
  final bool isConfirmation;

  _OnboardingStep({
    required this.title,
    required this.description,
    this.requestPermission,
    this.isConfirmation = false,
  });

  /// Check if permission for this step is already granted
  Future<bool> isAlreadyGranted() async {
    if (title.contains('Location')) {
      // 1️⃣ Check if GPS is enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      // 2️⃣ Check location permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      // 3️⃣ Try to get current position
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // 4️⃣ Optional: reverse geocode (not strictly required for granting)
        try {
          final placemarks = await placemarkFromCoordinates(
            pos.latitude,
            pos.longitude,
          );
          if (placemarks.isEmpty) return false;
        } catch (_) {
          return false;
        }

        return true; // ✅ GPS + permission + position success
      } catch (_) {
        return false;
      }
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

class _OnboardingPage extends StatelessWidget {
  final _OnboardingStep step;
  final bool isLastStep;

  const _OnboardingPage({
    super.key,
    required this.step,
    required this.isLastStep,
  });

  IconData _iconForStep(String title) {
    if (title.contains('Location')) return Icons.location_on_rounded;
    if (title.contains('Notification')) return Icons.notifications_active;
    if (title.contains('Battery')) return Icons.battery_saver;
    if (title.contains('Exact')) return Icons.alarm;
    if (title.contains('Confirm')) return Icons.check_circle_rounded;
    return Icons.check_circle;
  }

  @override
  Widget build(BuildContext context) {
    // If last step is the confirmation, show custom UI
    if (step.isConfirmation) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _iconForStep(step.title),
              size: 120,
              color: const Color(0xFF1FA45B),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                step.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Default onboarding step UI
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: const Color(0xFF1FA45B).withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconForStep(step.title),
              size: 56,
              color: const Color(0xFF1FA45B),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            step.title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            step.description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SuccessAnimation extends StatefulWidget {
  @override
  State<_SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<_SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.check_circle_rounded,
              size: 120,
              color: Color(0xFF1FA45B),
            ),
            SizedBox(height: 24),
            Text(
              'All Set!',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Saleti is ready to help you stay on time with your prayers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Returns true if the user has completed onboarding
Future<bool> hasCompletedOnboarding() async {
  final box = Hive.box('app');
  return box.get('onboardingCompleted', defaultValue: false);
}

/// Marks onboarding as completed
Future<void> setOnboardingCompleted() async {
  final box = Hive.box('app');
  await box.put('onboardingCompleted', true);
}
