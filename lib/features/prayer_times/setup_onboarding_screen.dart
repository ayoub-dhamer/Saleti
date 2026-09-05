import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/battery_optimization_permission.dart';
import '../../utils/exact_alarm_permission.dart';
import '../home/home_screen.dart';

const Color primaryGreen = Color(0xFF1FA45B);
const Color secondaryGreen = Color(0xFF4FC3A1);

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
  bool _isProcessing = false;

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
      _OnboardingStep(
        title: 'Confirm Setup',
        description: 'Everything is ready. You can start using Saleti.',
        isConfirmation: true,
      ),
    ]);

    _skipGrantedSteps();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _skipGrantedSteps() async {
    int stepIndex = 0;
    for (final step in _steps) {
      final granted = await step.isAlreadyGranted();
      if (granted) {
        stepIndex++;
      } else {
        break;
      }
    }

    _currentStep = stepIndex.clamp(0, _steps.length - 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.hasClients && _currentStep > 0) {
        _controller.jumpToPage(_currentStep);
      }
      if (mounted) setState(() {});
    });
  }

  Future<void> _nextStep() async {
    if (_isProcessing) return;
    final current = _steps[_currentStep];

    setState(() => _isProcessing = true);
    HapticFeedback.selectionClick();

    bool granted = true;

    if (!current.isConfirmation) {
      if (current.requestPermission == null) {
        setState(() => _isProcessing = false);
        return;
      }
      granted = await current.requestPermission!();
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (!granted) return;

    int nextStep = _currentStep + 1;

    while (nextStep < _steps.length) {
      if (await _steps[nextStep].isAlreadyGranted()) {
        nextStep++;
      } else {
        break;
      }
    }

    if (nextStep < _steps.length) {
      HapticFeedback.lightImpact();
      setState(() => _currentStep = nextStep);
      if (_controller.hasClients) {
        _controller.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    } else {
      HapticFeedback.mediumImpact();
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
    await Geolocator.isLocationServiceEnabled();

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return false;

      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _PermissionDialog(
          title: 'Location Permission Required',
          message:
              'Location access has been permanently denied. Please enable it from system settings to continue.',
        ),
      );

      if (retry == true) {
        await Geolocator.openAppSettings();
        return _requestLocation();
      }

      return false;
    }

    final granted =
        permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;

    if (!granted && mounted) {
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _PermissionDialog(
          title: 'Location Required',
          message: 'You must allow location access to continue using Saleti.',
        ),
      );

      if (retry == true) {
        return _requestLocation();
      }
    }

    return granted;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _steps[_currentStep];
    final progress = (_currentStep + 1) / _steps.length;

    return Scaffold(
      backgroundColor: theme
          .scaffoldBackgroundColor, // CHANGED: was hardcoded Color(0xFFF6F8FA)
      body: SafeArea(
        child: Column(
          children: [
            // Top brand mark + progress
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [primaryGreen, secondaryGreen],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mosque,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Saleti Setup',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_currentStep + 1}/${_steps.length}',
                    style: TextStyle(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(
                        0.5,
                      ),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: theme.brightness == Brightness.dark
                          ? Colors.white12
                          : Colors.grey.shade200, // CHANGED
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        primaryGreen,
                      ),
                    ),
                  );
                },
              ),
            ),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (child, animation) {
                  final slide =
                      Tween<Offset>(
                        begin: const Offset(0.15, 0),
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
                  key: ValueKey(_currentStep),
                  step: step,
                  isLastStep: _currentStep == _steps.length - 1,
                ),
              ),
            ),

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
                    width: _currentStep == index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: _currentStep >= index
                          ? const LinearGradient(
                              colors: [primaryGreen, secondaryGreen],
                            )
                          : null,
                      color: _currentStep >= index
                          ? null
                          : (theme.brightness == Brightness.dark
                                ? Colors.white24
                                : Colors.grey.shade300), // CHANGED
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),

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
                child: SizedBox(
                  key: ValueKey('$_currentStep-$_isProcessing'),
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      disabledBackgroundColor: primaryGreen.withOpacity(0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 3,
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.4,
                            ),
                          )
                        : Text(
                            _currentStep == _steps.length - 1
                                ? 'Confirm & Start'
                                : 'Continue',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: .3,
                              color: Colors.white,
                            ),
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

/// Restyled permission dialog matching the app's language.
class _PermissionDialog extends StatelessWidget {
  final String title;
  final String message;

  const _PermissionDialog({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor, // CHANGED: was hardcoded Colors.white
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                theme.brightness == Brightness.dark ? 0.4 : 0.15,
              ),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ), // CHANGED
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: primaryGreen,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white24
                            : Colors.grey.shade300,
                      ), // CHANGED
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
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

  Future<bool> isAlreadyGranted() async {
    if (title.contains('Location')) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        try {
          final placemarks = await placemarkFromCoordinates(
            pos.latitude,
            pos.longitude,
          );
          if (placemarks.isEmpty) return false;
        } catch (_) {
          return false;
        }

        return true;
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
    if (title.contains('Notification'))
      return Icons.notifications_active_rounded;
    if (title.contains('Battery')) return Icons.battery_saver_rounded;
    if (title.contains('Exact')) return Icons.alarm_rounded;
    if (title.contains('Confirm')) return Icons.check_circle_rounded;
    return Icons.check_circle;
  }

  String _whyItMatters(String title) {
    if (title.contains('Location'))
      return 'Used only to calculate Fajr, Dhuhr, Asr, Maghrib and Isha for your area.';
    if (title.contains('Notification'))
      return 'Lets Saleti alert you a few minutes before each prayer.';
    if (title.contains('Battery'))
      return 'Without this, Android may silence the Azan while the screen is off.';
    if (title.contains('Exact'))
      return 'Keeps prayer alerts accurate to the minute.';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (step.isConfirmation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, t, child) =>
                    Transform.scale(scale: t.clamp(0.0, 1.2), child: child),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [primaryGreen, secondaryGreen],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: primaryGreen.withOpacity(0.35),
                        blurRadius: 30,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'All Set!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                step.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final why = _whyItMatters(step.title);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryGreen.withOpacity(0.12),
                    secondaryGreen.withOpacity(0.12),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForStep(step.title),
                size: 58,
                color: primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            step.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            step.description,
            style: TextStyle(
              fontSize: 15,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          if (why.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: primaryGreen.withOpacity(
                  theme.brightness == Brightness.dark ? 0.12 : 0.06,
                ), // CHANGED: slightly stronger tint in dark mode for visibility
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: primaryGreen.withOpacity(0.9),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      why,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: primaryGreen.withOpacity(0.95),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
