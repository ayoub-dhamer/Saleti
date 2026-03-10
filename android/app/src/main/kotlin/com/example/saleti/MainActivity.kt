package com.example.saleti

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

class MainActivity : FlutterActivity() {

    private val CHANNEL = "azan_service"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                when (call.method) {
                    "startAzan" -> {
                        val prayer = call.arguments?.let { (it as? Map<*, *>)?.get("prayer") as? String } ?: "Prayer"
                        val intent = Intent(this, AzanService::class.java)
                        intent.putExtra("prayer", prayer)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
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

                        val intent = Intent(this, AzanService::class.java)
                        intent.putExtra("prayer", prayer)

                        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            PendingIntent.getForegroundService(
                                this,
                                id,
                                intent,
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                        } else {
                            PendingIntent.getService(
                                this,
                                id,
                                intent,
                                PendingIntent.FLAG_UPDATE_CURRENT
                            )
                        }

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

                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}