import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';

class BatteryOptimizationHelper {
  static Future<void> requestDisable(BuildContext context) async {
    if (!Platform.isAndroid) return;

    if (!context.mounted) return;

    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Disable Battery Optimization'),
        content: const Text(
          'To ensure Azan and prayer reminders work reliably, '
          'please disable battery optimization for this app.\n\n'
          'On the next screen:\n'
          '• Choose "All apps"\n'
          '• Select "Saleti"\n'
          '• Choose "Don\'t optimize"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (allow == true) {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
        data: 'package:com.example.saleti', // ⚠️ CHANGE IF NEEDED
      );

      await intent.launch();
    }
  }
}
