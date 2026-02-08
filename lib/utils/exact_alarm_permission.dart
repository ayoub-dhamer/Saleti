import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class ExactAlarmPermission {
  static const _askedKey = 'asked_exact_alarm';

  /// ✅ Checks if the system has actually granted the permission
  static Future<bool> isGranted() async {
    if (!Platform.isAndroid) return true;
    return await Permission.scheduleExactAlarm.isGranted;
  }

  static Future<void> ensureEnabled(BuildContext context) async {
    if (!Platform.isAndroid) return;

    // 1. If already granted by system, stop here
    if (await isGranted()) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_askedKey) ?? false;

    // 2. Prevent spamming the user if they already saw this once
    if (alreadyAsked) return;

    if (!context.mounted) return;

    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.alarm, color: Colors.blue),
            SizedBox(width: 10),
            Text('Allow Exact Alarms'),
          ],
        ),
        content: const Text(
          'Exact alarms are required so Azan and prayer reminders ring on time.\n\n'
          'Please enable "Allow setting alarms and reminders" on the next screen.',
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

    // 3. Mark as asked so we don't prompt again
    await prefs.setBool(_askedKey, true);

    if (allow == true) {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      );
      await intent.launch();
    }
  }
}
