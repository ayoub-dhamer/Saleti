package com.saleti.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.telephony.PhoneStateListener
import android.telephony.TelephonyCallback
import android.telephony.TelephonyManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.util.concurrent.Executor

class AzanService : Service() {

    companion object {
        const val ACTION_PLAY_AZAN = "com.saleti.app.action.PLAY_AZAN"
        const val ACTION_STOP_AZAN = "com.saleti.app.action.STOP_AZAN"
    }

    private var mediaPlayer: MediaPlayer? = null
    private val CHANNEL_ID = "azan_foreground_channel"
    private var prayerName: String = "Prayer"
    private var volume: Float = 1.0f
    private var azanEnabled: Boolean = true

    private var telephonyManager: TelephonyManager? = null
    private var shouldResumeAfterCall = false
    private var isListeningToCallState = false

    // Modern path (API 31 / Android 12+, which covers Android 16 devices).
    private var telephonyCallback: TelephonyCallback? = null

    // Legacy fallback, only exercised if your minSdk is below 31.
    private var phoneStateListener: PhoneStateListener? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP_AZAN -> {
                stopAzan()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_PLAY_AZAN -> {
                // continue below
            }
            else -> {
                stopSelf()
                return START_NOT_STICKY
            }
        }

        prayerName = intent?.getStringExtra("prayer") ?: "Prayer"
        volume = intent?.getFloatExtra("volume", 1.0f) ?: 1.0f
        azanEnabled = intent?.getBooleanExtra("azanEnabled", true) ?: true

        if (!azanEnabled) {
            stopSelf()
            return START_NOT_STICKY
        }

        createNotificationChannel()
        startForegroundNotification()
        registerCallStateListener()
        startAzan()
        return START_STICKY
    }

    private fun startForegroundNotification() {
        val stopIntent = Intent(this, AzanService::class.java).apply {
            action = ACTION_STOP_AZAN
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

    /// Pauses the Azan for the duration of a phone call and resumes it
    /// automatically when the call ends, as long as this prayer's Azan
    /// is still enabled. Uses TelephonyCallback on API 31+ (PhoneStateListener
    /// is deprecated there); falls back to PhoneStateListener below API 31.
    private fun registerCallStateListener() {
        if (isListeningToCallState) return

        telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        if (telephonyManager == null) return

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                // ---- API 31+ path ----
                val callback = object : TelephonyCallback(), TelephonyCallback.CallStateListener {
                    override fun onCallStateChanged(state: Int) {
                        handleCallStateChanged(state)
                    }
                }
                val executor: Executor = ContextCompat.getMainExecutor(this)
                telephonyManager?.registerTelephonyCallback(executor, callback)
                telephonyCallback = callback
            } else {
                // ---- Legacy fallback for minSdk < 31 ----
                // DELETE this whole `else` branch (and the phoneStateListener
                // field + unregister call below) once your minSdk is raised to 31+.
                @Suppress("DEPRECATION")
                val listener = object : PhoneStateListener() {
                    @Suppress("DEPRECATION")
                    override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                        super.onCallStateChanged(state, phoneNumber)
                        handleCallStateChanged(state)
                    }
                }
                @Suppress("DEPRECATION")
                telephonyManager?.listen(listener, PhoneStateListener.LISTEN_CALL_STATE)
                phoneStateListener = listener
            }
            isListeningToCallState = true
        } catch (e: SecurityException) {
            // READ_PHONE_STATE not granted or restricted — degrade gracefully,
            // Azan just won't pause for calls on this device/user.
            e.printStackTrace()
        }
    }

    /// Shared state-change handling for both the TelephonyCallback and
    /// PhoneStateListener paths, so the pause/resume logic lives in one place.
    private fun handleCallStateChanged(state: Int) {
        when (state) {
            TelephonyManager.CALL_STATE_RINGING,
            TelephonyManager.CALL_STATE_OFFHOOK -> {
                if (mediaPlayer?.isPlaying == true) {
                    shouldResumeAfterCall = true
                    pauseForCall()
                }
            }
            TelephonyManager.CALL_STATE_IDLE -> {
                if (shouldResumeAfterCall && azanEnabled) {
                    shouldResumeAfterCall = false
                    resumeAfterCall()
                }
            }
        }
    }

    private fun unregisterCallStateListener() {
        if (!isListeningToCallState) return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            telephonyCallback?.let { telephonyManager?.unregisterTelephonyCallback(it) }
            telephonyCallback = null
        } else {
            @Suppress("DEPRECATION")
            telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_NONE)
            phoneStateListener = null
        }
        isListeningToCallState = false
    }

    private fun pauseForCall() {
        mediaPlayer?.let {
            if (it.isPlaying) it.pause()
        }
    }

    private fun resumeAfterCall() {
        mediaPlayer?.let {
            try {
                it.start()
            } catch (e: Exception) {
                // Player may have already been released by a STOP action
                // that arrived while the call was in progress — just bail.
                e.printStackTrace()
            }
        }
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
        shouldResumeAfterCall = false
        stopForeground(true)
        stopSelf()
    }

    override fun onDestroy() {
        unregisterCallStateListener()
        stopAzan()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}