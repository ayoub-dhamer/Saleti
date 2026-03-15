package com.example.saleti

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
                        val azanEnabled = true // we only schedule if toggle is ON

                        scheduleAzan(id, prayer, timestamp, volume, azanEnabled)
                        result.success(null)
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

    private fun scheduleAzan(id: Int, prayer: String, timestamp: Long, volume: Float, azanEnabled: Boolean) {
        val pendingIntent = getAzanPendingIntent(id, prayer, volume, azanEnabled)
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

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
    }

    private fun cancelAzan(id: Int) {
        val dummyPrayer = "dummy" // prayer string doesn’t matter for cancelling
        val dummyVolume = 1.0f
        val dummyAzan = true

        val pendingIntent = getAzanPendingIntent(id, dummyPrayer, dummyVolume, dummyAzan)
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }
}