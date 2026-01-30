import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';

class ExactAlarmHelper {
  static Future<void> requestPermission(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Allow Exact Alarms'),
        content: const Text(
          'To ensure Azan and prayer reminders work on time, '
          'please allow Exact Alarms.\n\n'
          'On the next screen:\n'
          '• Enable "Allow exact alarms"',
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
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      );
      await intent.launch();
    }
  }
}
