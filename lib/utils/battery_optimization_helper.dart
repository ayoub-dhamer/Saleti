import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BatteryOptimizationHelper {
  static Future<bool> isWhitelisted() async {
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }

  static const _askedKey = 'asked_battery_optimization';

  static Future<void> requestDisable(BuildContext context) async {
    // 1. Check current status
    final status = await Permission.ignoreBatteryOptimizations.status;

    // 2. If already granted, do nothing
    if (status.isGranted) {
      debugPrint("Battery Optimization already disabled ✅");
      return;
    }

    // 3. Show a user-friendly explanation (Android requirements)
    if (context.mounted) {
      bool? proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.battery_saver, color: Colors.orange),
              SizedBox(width: 10),
              Text('Battery Optimization'),
            ],
          ),
          content: const Text(
            'To ensure the Azan plays exactly on time while your phone is locked, '
            'please set Saleti to "Don\'t Optimize" in the next screen.\n\n'
            'This is required by Android for apps that use Alarms.',
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

      // 4. If user agrees, request the permission
      if (proceed == true) {
        // This triggers the system "Allow app to stay active in background?" popup
        final requestStatus = await Permission.ignoreBatteryOptimizations
            .request();

        if (requestStatus.isDenied) {
          debugPrint("User denied battery optimization whitelist.");
        }
      }
    }
  }
}
