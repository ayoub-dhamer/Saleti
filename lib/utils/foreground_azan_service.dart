import 'dart:isolate';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:just_audio/just_audio.dart';

class PrayerTaskHandler extends TaskHandler {
  AudioPlayer? _player;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    _player = AudioPlayer();

    await _player!.setAsset('assets/audio/azan.mp3');
    await _player!.play();

    // ✅ Stop service when azan finishes
    _player!.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        await FlutterForegroundTask.stopService();
      }
    });
  }

  @override
  void onNotificationButtonPressed(String id) async {
    if (id == 'stop') {
      await FlutterForegroundTask.stopService();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    await _player?.dispose();
    _player = null;
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp();
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) {}
}
