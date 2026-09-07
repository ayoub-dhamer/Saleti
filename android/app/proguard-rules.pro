# flutter_local_notifications
-keep class com.dexterous.** { *; }

# geolocator
-keep class com.baseflow.geolocator.** { *; }

# Hive + generated adapters
-keep class * extends com.hive_flutter.** { *; }
-keep class **$*Adapter { *; }
-keepclassmembers class * extends com.hive_flutter.HiveObject { *; }

# android_alarm_manager_plus (uses reflection to invoke Dart callbacks)
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }

# adhan (prayer time calculation library)
-keep class com.batoulapps.adhan.** { *; }

# General Flutter plugin safety net
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.**  { *; }