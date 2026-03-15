package com.example.saleti

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import androidx.core.app.NotificationCompat
import org.json.JSONObject

class AzanService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private val CHANNEL_ID = "azan_foreground_channel"
    private val STOP_ACTION = "com.example.saleti.STOP_AZAN"
    private var prayerName: String = "Prayer"
    private var volume: Float = 1.0f

    private var telephonyManager: TelephonyManager? = null
    private var phoneStateListener: PhoneStateListener? = null
    private var shouldResumeAfterCall = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

    // Handle STOP action from notification
    if (intent?.action == STOP_ACTION) {
        stopAzan()
        return START_NOT_STICKY
    }

    prayerName = intent?.getStringExtra("prayer") ?: "Prayer"
    volume = intent?.getFloatExtra("volume", 1.0f) ?: 1.0f

    // ❗ Check if this prayer's azan is enabled
    val azanEnabled = intent?.getBooleanExtra("azanEnabled", true) ?: true

    createNotificationChannel()
    startForegroundNotification()

    telephonyManager = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
    phoneStateListener = object : PhoneStateListener() {
        override fun onCallStateChanged(state: Int, phoneNumber: String?) {
            super.onCallStateChanged(state, phoneNumber)
            when (state) {
                TelephonyManager.CALL_STATE_RINGING,
                TelephonyManager.CALL_STATE_OFFHOOK -> {
                    if (mediaPlayer?.isPlaying == true) shouldResumeAfterCall = true
                    stopAzan()
                }
                TelephonyManager.CALL_STATE_IDLE -> {
                    if (shouldResumeAfterCall && azanEnabled) {
                        shouldResumeAfterCall = false
                        startAzan()
                    }
                }
            }
        }
    }
    telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)

    if (azanEnabled) startAzan() // Only start Azan if this prayer has it enabled
    return START_STICKY
}

    private fun startForegroundNotification() {
        val stopIntent = Intent(this, AzanService::class.java).apply {
            action = STOP_ACTION
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 0, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification: Notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Time for $prayerName Prayer")
            .setContentText("Salah is a meeting with the One who loves you most")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .addAction(R.mipmap.ic_launcher, "STOP", stopPendingIntent)
            .build()

        startForeground(1, notification)
    }

    fun startAzan() {
        try {
            mediaPlayer?.release()
            mediaPlayer = MediaPlayer()

            val afd = resources.openRawResourceFd(R.raw.azan) ?: return
            mediaPlayer?.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()

            mediaPlayer?.isLooping = false
            mediaPlayer?.setVolume(volume, volume)
            mediaPlayer?.setAudioStreamType(AudioManager.STREAM_ALARM)
            mediaPlayer?.setOnPreparedListener { it.start() }
            mediaPlayer?.setOnCompletionListener { stopAzan() }
            mediaPlayer?.prepareAsync()
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

    fun stopAzan() {
        mediaPlayer?.let {
            if (it.isPlaying) it.stop()
            it.release()
        }
        mediaPlayer = null
        stopForeground(true)
    }

    override fun onDestroy() {
        telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
        stopAzan()
        super.onDestroy()
    }

    private fun isAzanEnabled(): Boolean {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.prayer_settings", null) ?: return true
        val decoded = JSONObject(raw)
        return decoded.optJSONObject(prayerName)?.optBoolean("azan", true) ?: true
    }

    override fun onBind(intent: Intent?): IBinder? = null
}