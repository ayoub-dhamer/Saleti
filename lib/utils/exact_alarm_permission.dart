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
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        data:
            'package:com.example.saleti.app', // CHANGED (was 'package:your.package.name')
      );

      try {
        await intent.launch();
      } catch (e) {
        const fallbackIntent = AndroidIntent(
          action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        );
        await fallbackIntent.launch();
      }
    }
  }
}
