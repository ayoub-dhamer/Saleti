package com.saleti.azan_platform

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class AzanPlatformPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "azan_service")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            

            "stopAzan" -> {
                appContext.stopService(azanServiceIntent())
                result.success(null)
            }

            "scheduleAzanNative" -> {
                val args = call.arguments as? Map<*, *>
                val id = args?.get("id") as? Int ?: 0
                val timestamp = args?.get("timestamp") as? Long ?: 0L
                val prayer = args?.get("prayer") as? String ?: "Prayer"
                val volume = (args?.get("volume") as? Double ?: 1.0).toFloat()
                val azanEnabled = args?.get("azanEnabled") as? Boolean ?: true

                val scheduled = if (azanEnabled) {
                    scheduleAzan(id, prayer, timestamp, volume)
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

            "startFridayReminder" -> {
                ContextCompat.startForegroundService(appContext, fridayIntent(ACTION_FRIDAY_START))
                result.success(null)
            }

            "stopFridayReminder" -> {
                appContext.startService(fridayIntent(ACTION_FRIDAY_STOP))
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    // -----------------------------
    // Component targeting by string, not compile-time class refs — keeps
    // this plugin free of any dependency on the host app's Kotlin classes.
    // The action-string constants below must stay in sync with whatever
    // AzanService.kt / FridayReminderService.kt actually check for.
    // -----------------------------

    private fun azanServiceIntent(): Intent =
        Intent().setClassName(appContext.packageName, "${appContext.packageName}.AzanService")

    private fun fridayIntent(action: String): Intent =
        Intent()
            .setClassName(appContext.packageName, "${appContext.packageName}.FridayReminderService")
            .setAction(action)

    private fun getAzanPendingIntent(id: Int, prayer: String, volume: Float): PendingIntent {
        val intent = azanServiceIntent().apply {
            action = ACTION_PLAY_AZAN
            putExtra("prayer", prayer)
            putExtra("volume", volume)
            putExtra("azanEnabled", true)
        }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(appContext, id, intent, flags)
        } else {
            PendingIntent.getService(appContext, id, intent, flags)
        }
    }

    private fun scheduleAzan(id: Int, prayer: String, timestamp: Long, volume: Float): Boolean {
        val pendingIntent = getAzanPendingIntent(id, prayer, volume)
        val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, timestamp, pendingIntent)
            } else {
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, timestamp, pendingIntent)
            }
            true
        } catch (e: SecurityException) {
            e.printStackTrace()
            false
        }
    }

    private fun cancelAzan(id: Int) {
        val intent = azanServiceIntent().apply { action = ACTION_PLAY_AZAN }

        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(appContext, id, intent, flags)
        } else {
            PendingIntent.getService(appContext, id, intent, flags)
        }

        val alarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
    }

    companion object {
        private const val ACTION_PLAY_AZAN = "com.saleti.app.action.PLAY_AZAN"
        private const val ACTION_FRIDAY_START = "com.saleti.app.action.START_FRIDAY_REMINDER"
        private const val ACTION_FRIDAY_STOP = "com.saleti.app.action.STOP_FRIDAY_REMINDER"
    }
}