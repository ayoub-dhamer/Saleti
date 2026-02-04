import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class ForegroundService {
  static Future<void> start() async {
    await FlutterForegroundTask.startService(
      notificationTitle: 'Prayer times active',
      notificationText: 'Notifications will trigger on time',
      callback: startCallback,
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
  }
}

/// REQUIRED top-level callback
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(PrayerTaskHandler());
}

class PrayerTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {}

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {}

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }
}
