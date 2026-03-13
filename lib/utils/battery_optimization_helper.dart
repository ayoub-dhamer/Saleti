import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class BatteryOptimizationHelper {
  /// Check if the app is already whitelisted
  static Future<bool> isWhitelisted() async {
    return await Permission.ignoreBatteryOptimizations.isGranted;
  }

  /// Directly request battery optimization permission without showing a dialog
  static Future<void> requestDisable() async {
    final status = await Permission.ignoreBatteryOptimizations.status;

    if (!status.isGranted) {
      final requestStatus = await Permission.ignoreBatteryOptimizations
          .request();

      if (requestStatus.isDenied) {
        debugPrint("User denied battery optimization whitelist.");
      } else {
        debugPrint("Battery optimization disabled ✅");
      }
    } else {
      debugPrint("Battery Optimization already disabled ✅");
    }
  }
}
