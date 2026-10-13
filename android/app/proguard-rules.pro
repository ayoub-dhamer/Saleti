# flutter_local_notifications
-keep class com.dexterous.** { *; }

# FIXED (polish #12): flutter_local_notifications uses Gson internally for
# scheduled/persisted notification data (zonedSchedule, periodic
# notifications, anything that needs to survive a reboot). R8 can strip
# the generic type signatures and TypeToken subclasses Gson needs at
# runtime for that, without these two lines — there's a real report of
# this breaking in release builds specifically. This app mostly calls
# show() directly from a Dart-side alarm callback rather than using this
# plugin's own native scheduling, so it's less exposed than apps that
# lean on zonedSchedule — but keeping these is cheap insurance against
# any internal code path that still touches Gson.
-keepattributes Signature
-keep class * extends com.google.gson.reflect.TypeToken

# geolocator
-keep class com.baseflow.geolocator.** { *; }

# FIXED (polish #12): removed the three "Hive + generated adapters" rules
# that were here (-keep class * extends com.hive_flutter.**, -keep class
# **$*Adapter, -keepclassmembers class * extends
# com.hive_flutter.HiveObject). Hive and its generated TypeAdapter classes
# (KhatmYearAdapter, SurahGoalAdapter, ...) are pure Dart, AOT-compiled to
# native code — not JVM bytecode. R8/ProGuard only ever processes the
# Java/Kotlin layer, so there was never a com.hive_flutter package or a
# *$*Adapter class for these rules to match in the first place; they were
# inert from the day they were added. There's nothing to keep here because
# there's nothing for R8 to strip.

# android_alarm_manager_plus (uses reflection to invoke Dart callbacks)
-keep class dev.fluttercommunity.plus.androidalarmmanager.** { *; }

# adhan (prayer time calculation library)
-keep class com.batoulapps.adhan.** { *; }

# General Flutter plugin safety net
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.**  { *; }