package com.saleti.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "azan_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {
                    "startAzan" -> {
                        val prayer = (call.arguments as? Map<*, *>)?.get("prayer") as? String ?: "Prayer"
                        val intent = Intent(this, AzanService::class.java).apply {
                            putExtra("prayer", prayer)
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
                        else startService(intent)
                        result.success(null)
                    }

                    "stopAzan" -> {
                        stopService(Intent(this, AzanService::class.java))
                        result.success(null)
                    }

                    "scheduleAzanNative" -> {
                        val args = call.arguments as? Map<*, *>
                        val id = args?.get("id") as? Int ?: 0
                        val timestamp = args?.get("timestamp") as? Long ?: 0L
                        val prayer = args?.get("prayer") as? String ?: "Prayer"
                        val volume = (args?.get("volume") as? Double ?: 1.0).toFloat()
                        val azanEnabled = args?.get("azanEnabled") as? Boolean ?: true

                        // CHANGED: scheduleAzan/cancelAzan now report success/failure
                        // back through `result` instead of always calling result.success(null)
                        // unconditionally, so Dart can know if scheduling silently failed.
                        val scheduled = if (azanEnabled) {
                            scheduleAzan(id, prayer, timestamp, volume, azanEnabled)
                        } else {
                            cancelAzan(id)
                            true
                        }

                        if (scheduled) {
                            result.success(null)
                        } else {
                            result.error(
                                "SCHEDULE_FAILED",
                                "Could not schedule exact alarm — permission may have been revoked",
                                null
                            )
                        }
                    }

                    "cancelAzanNative" -> {
                        val args = call.arguments as? Map<*, *>
                        val id = args?.get("id") as? Int ?: 0
                        cancelAzan(id)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // -----------------------------
    // AZAN SCHEDULING HELPERS
    // -----------------------------

    private fun getAzanPendingIntent(
        id: Int,
        prayer: String,
        volume: Float,
        azanEnabled: Boolean
    ): PendingIntent {
        val intent = Intent(this, AzanService::class.java).apply {
            action = AzanService.ACTION_PLAY_AZAN
            putExtra("prayer", prayer)
            putExtra("volume", volume)
            putExtra("azanEnabled", azanEnabled)
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(this, id, intent, flags)
        } else {
            PendingIntent.getService(this, id, intent, flags)
        }
    }

    /// Returns true if the exact alarm was scheduled successfully, false if
    /// it failed (most likely SCHEDULE_EXACT_ALARM was revoked by the user
    /// after onboarding — this permission can be pulled at any time from
    /// system settings, independent of what was granted at first launch).
    private fun scheduleAzan(
        id: Int,
        prayer: String,
        timestamp: Long,
        volume: Float,
        azanEnabled: Boolean
    ): Boolean {
        val pendingIntent = getAzanPendingIntent(id, prayer, volume, azanEnabled)
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    timestamp,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    timestamp,
                    pendingIntent
                )
            }
            true
        } catch (e: SecurityException) {
            // SCHEDULE_EXACT_ALARM revoked — degrade silently rather than
            // crash the method channel call from Dart. Caller reports this
            // back to Dart via result.error so it's not a silent failure there.
            e.printStackTrace()
            false
        }
    }

    private fun cancelAzan(id: Int) {
        val intent = Intent(this, AzanService::class.java).apply {
            action = AzanService.ACTION_PLAY_AZAN
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(this, id, intent, flags)
        } else {
            PendingIntent.getService(this, id, intent, flags)
        }

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }
}