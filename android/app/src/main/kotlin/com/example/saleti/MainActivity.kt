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
                    "startAzan" -> startAzan(call, result)
                    "stopAzan" -> stopAzan(call, result)
                    "scheduleAzanNative" -> scheduleAzanNative(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun startAzan(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val intent = Intent(this, AzanService::class.java)
        intent.putExtra("prayer", call.argument<String>("prayer"))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
        result.success(null)
    }

    private fun stopAzan(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        stopService(Intent(this, AzanService::class.java))
        result.success(null)
    }

    private fun scheduleAzanNative(call: MethodChannel.MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Int>("id")!!
        val timestamp = call.argument<Long>("timestamp")!!
        val prayer = call.argument<String>("prayer")!!

        val intent = Intent(this, AzanService::class.java)
        intent.putExtra("prayer", prayer)

        // PendingIntent for foreground service
        val pendingIntent = PendingIntent.getForegroundService(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        // Set exact alarm even in Doze mode
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
}