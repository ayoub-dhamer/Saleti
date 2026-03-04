package com.example.saleti

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.MediaPlayer
import android.media.AudioManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class AzanService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private val CHANNEL_ID = "azan_foreground_channel"
    private val STOP_ACTION = "com.example.saleti.STOP_AZAN"
    private var prayerName: String = "Prayer"

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

        // Handle STOP action from notification
        if (intent?.action == STOP_ACTION) {
            stopAzan()
            return START_NOT_STICKY
        }

        prayerName = intent?.getStringExtra("prayer") ?: "Prayer"

        createNotificationChannel()

        val stopIntent = Intent(this, AzanService::class.java).apply {
            action = STOP_ACTION
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Time for $prayerName Prayer")
            .setContentText("Salah is not a burden; it is a meeting with the One who loves you most")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .addAction(R.mipmap.ic_launcher, "STOP", stopPendingIntent)
            .build()

        startForeground(1, notification)

        startAzan()

        return START_STICKY
    }

    private fun startAzan() {
    try {
        mediaPlayer?.release()
        mediaPlayer = MediaPlayer()

        // Load audio without startup pop
        val afd = resources.openRawResourceFd(R.raw.azan) ?: return
        mediaPlayer?.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
        afd.close()

        mediaPlayer?.isLooping = false
        mediaPlayer?.setVolume(1.0f, 1.0f)
        mediaPlayer?.setAudioStreamType(AudioManager.STREAM_ALARM) // Use alarm stream
        mediaPlayer?.setOnPreparedListener {
            it.start() // Start only when fully prepared
        }
        mediaPlayer?.setOnCompletionListener { stopAzan() }

        mediaPlayer?.prepareAsync() // Async preparation avoids the pop
    } catch (e: Exception) {
        e.printStackTrace()
        stopAzan()
    }
}

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Azan Service",
                NotificationManager.IMPORTANCE_HIGH
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun stopAzan() {
        mediaPlayer?.let {
            if (it.isPlaying) it.stop()
            it.release()
        }
        mediaPlayer = null
        stopForeground(true)
        stopSelf()
    }

    override fun onDestroy() {
        stopAzan()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}