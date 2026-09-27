import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class ExactAlarmPermission {
  static Future<bool> isGranted() async {
    if (!Platform.isAndroid) return true;
    // scheduleExactAlarm is the specific check for this permission
    return await Permission.scheduleExactAlarm.isGranted;
  }

  // FIXED (bug #5): this used to open Android's exact-alarm settings
  // screen via a manually-built intent with the data URI
  // 'package:com.example.saleti.app' hardcoded — but this app's real
  // applicationId is 'com.saleti.app' (see build.gradle.kts). That
  // settings screen was for a package that doesn't exist on the device,
  // so the toggle the user saw and enabled there could never actually
  // grant *this* app anything: isGranted() would keep reporting false no
  // matter what the user did, and — since onboarding has no skip button —
  // that stranded the user on this step permanently.
  //
  // Permission.scheduleExactAlarm.request() asks the OS for this app's
  // own exact-alarm settings screen directly, so there's no package
  // string to get wrong, and it no longer needs a BuildContext.
  static Future<void> ensureEnabled() async {
    if (!Platform.isAndroid) return;
    if (!(await isGranted())) {
      await Permission.scheduleExactAlarm.request();
    }
  }
}
