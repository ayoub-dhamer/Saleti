package com.saleti.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/// Foreground-service-backed replacement for the old flutter_local_notifications
/// Friday reminder. A plain "ongoing" notification is swipeable on modern
/// Android regardless of the ongoing/autoCancel flags — only a notification
/// tied to a live foreground service is reliably non-dismissible by swipe,
/// which is why this mirrors AzanService's approach instead of using the
/// local-notifications plugin directly.
class FridayReminderService : Service() {

    companion object {
        const val ACTION_START = "com.saleti.app.action.START_FRIDAY_REMINDER"
        const val ACTION_STOP = "com.saleti.app.action.STOP_FRIDAY_REMINDER"
        const val NOTIFICATION_ID = 8888
        private const val CHANNEL_ID = "friday_reminder_channel"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }

        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        return START_STICKY
    }

    private fun buildNotification(): Notification {
        val stopIntent = Intent(this, FridayReminderService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("It's Jumu'ah Day")
            .setContentText(
                "Today is Friday — shower and read Surah Al-Kahf to get ready for Salat al-Jumu'ah."
            )
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setAutoCancel(false)
            .addAction(0, "Done", stopPendingIntent)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Friday Reminder",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "Weekly reminder to prepare for Salat al-Jumu'ah"
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null
}