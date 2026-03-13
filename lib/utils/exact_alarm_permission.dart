import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:android_intent_plus/android_intent.dart';

class ExactAlarmPermission {
  static Future<bool> isGranted() async {
    if (!Platform.isAndroid) return true;
    // scheduleExactAlarm is the specific check for this permission
    return await Permission.scheduleExactAlarm.isGranted;
  }

  static Future<void> ensureEnabled(BuildContext context) async {
    if (!Platform.isAndroid) return;

    if (!(await isGranted())) {
      // This is the specific Android Action for the "Alarms & Reminders" page
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        data:
            'package:your.package.name', // Replace with your actual package name (e.g., com.example.saleti)
      );

      try {
        await intent.launch();
      } catch (e) {
        // Fallback: If the specific package link fails, open the general list
        const fallbackIntent = AndroidIntent(
          action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        );
        await fallbackIntent.launch();
      }
    }
  }
}
