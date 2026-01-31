import 'dart:io';
import 'package:flutter/material.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExactAlarmPermission {
  static const _askedKey = 'asked_exact_alarm';

  static Future<void> ensureEnabled(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyAsked = prefs.getBool(_askedKey) ?? false;

    // ✅ If already asked once, do NOT spam
    if (alreadyAsked) return;

    if (!context.mounted) return;

    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Allow Exact Alarms'),
        content: const Text(
          'Exact alarms are required so Azan and prayer reminders ring on time.',
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

    // ✅ Mark as asked (IMPORTANT)
    await prefs.setBool(_askedKey, true);

    if (allow == true) {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      );
      await intent.launch();
    }
  }
}
