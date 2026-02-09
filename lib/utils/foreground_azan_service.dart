import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; // Add this to pubspec

class PrayerTaskHandler extends TaskHandler {
  AudioPlayer? _player;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    // 1. Force the CPU to stay awake while Azan is playing
    WakelockPlus.enable();

    _player = AudioPlayer();

    // 2. Advanced Audio Session Configuration
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.alarm, // 🚨 Set as Alarm usage for priority
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        // ^ This makes other apps get quieter instead of stopping the Azan
      ),
    );

    try {
      // 3. Asset Loading with Timeout
      await _player!.setAsset('assets/audio/azan.mp3');
      _player!.setVolume(1.0);

      // 4. Start playback and wait for it to finish
      await _player!.play();
    } catch (e) {
      print("Error playing azan: $e");
      // If audio fails, don't leave the service hanging
      await FlutterForegroundTask.stopService();
    }

    // 5. Listen for completion to clean up
    _player!.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        await _cleanupAndStop();
      }
    });
  }

  Future<void> _cleanupAndStop() async {
    WakelockPlus.disable(); // Allow CPU to sleep again
    await _player?.stop();
    await FlutterForegroundTask.stopService();
  }

  @override
  void onNotificationButtonPressed(String id) async {
    if (id == 'stop') {
      await _cleanupAndStop();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    WakelockPlus.disable();
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
