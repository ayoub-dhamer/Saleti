import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryOptimizationHelper {
  static const _askedKey = 'asked_battery_optimization';

  static Future<void> requestDisable(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_askedKey) ?? false;

    // ✅ Do not spam user
    if (alreadyAsked) return;

    if (!context.mounted) return;

    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Disable Battery Optimization'),
        content: const Text(
          'Battery optimization can prevent Azan from playing.\n\n'
          'Please allow unrestricted battery usage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    // ✅ Mark as asked
    await prefs.setBool(_askedKey, true);

    if (allow == true) {
      const intent = AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      );
      await intent.launch();
    }
  }
}
