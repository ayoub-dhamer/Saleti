import 'package:hive_flutter/hive_flutter.dart';

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
