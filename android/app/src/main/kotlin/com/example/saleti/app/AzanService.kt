package com.saleti.app

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
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

    // FIXED (Battery/CPU #8): see requestAudioFocus()/abandonAudioFocus()
    // below — holds the focus grant between the two so playback can
    // release it when done.
    private var audioManager: AudioManager? = null
    private var focusRequest: AudioFocusRequest? = null
    private var legacyFocusListener: AudioManager.OnAudioFocusChangeListener? = null

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
            .setSmallIcon(R.drawable.ic_notification)
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
                if (mediaPlayer?.isPlayingSafely() == true) {
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
            if (it.isPlayingSafely()) it.pause()
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

            // FIXED (Battery/CPU #8): was `?: return` — if this raw
            // resource can't be opened as a file descriptor (which
            // happens for real if the build ever compresses azan.mp3
            // into the APK instead of storing it raw — a small audio
            // file is exactly the kind of asset Android's packager will
            // compress unless told not to), this used to bail out of
            // startAzan() having already shown the foreground
            // notification and registered the call-state listener in
            // onStartCommand — leaving the service and its "ongoing"
            // notification stuck forever with no audio ever playing and
            // no automatic way out except the user noticing and tapping
            // STOP themselves. stopAzan() now always runs on this path
            // too, tearing the service back down properly.
            val afd = resources.openRawResourceFd(R.raw.azan)
            if (afd == null) {
                stopAzan()
                return
            }
            mediaPlayer?.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            afd.close()

            // FIXED (Battery/CPU #8): setAudioStreamType(STREAM_ALARM) is
            // deprecated since API 21 in favor of AudioAttributes — reused
            // below for the audio focus request too, so both agree this
            // is alarm-type audio.
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()

            mediaPlayer?.isLooping = false
            mediaPlayer?.setVolume(volume, volume)
            mediaPlayer?.setAudioAttributes(attributes)
            // FIXED (Battery/CPU #8): without this, the CPU is free to
            // sleep mid-playback if nothing else is keeping it awake —
            // plausible for exactly this use case, since Fajr often plays
            // while the phone is sitting idle on a nightstand with the
            // screen off.
            mediaPlayer?.setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)
            mediaPlayer?.setOnPreparedListener { it.start() }
            mediaPlayer?.setOnCompletionListener { stopAzan() }
            // FIXED (Battery/CPU #8): without this, a playback failure
            // (corrupt/truncated audio, a codec problem, ...) leaves the
            // player sitting in MediaPlayer's Error state with nothing
            // ever calling stopAzan() — and the *next* unrelated call to
            // isPlaying()/stop() on it (e.g. a phone call interrupting,
            // or this service's own onDestroy) would throw instead of
            // just reporting "not playing", since MediaPlayer's state
            // checks aren't exception-safe the way you'd expect. Handling
            // the error here tears things down immediately and safely.
            mediaPlayer?.setOnErrorListener { _, _, _ ->
                stopAzan()
                true
            }
            requestAudioFocus(attributes)
            mediaPlayer?.prepareAsync()
        } catch (e: Exception) {
            e.printStackTrace()
            stopAzan()
        }
    }

    /// Requests transient audio focus so the Azan ducks/pauses whatever
    /// else is playing (music, a podcast, ...) instead of overlapping it.
    /// Not gated on whether focus is actually granted — a prayer
    /// reminder failing to play because some other app held onto focus
    /// would be worse than the two overlapping, so this plays regardless
    /// either way, the same tradeoff real alarm-clock apps make.
    private fun requestAudioFocus(attributes: AudioAttributes) {
        val manager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
        audioManager = manager

        // AudioFocusRequest itself is API 26+; this file already branches
        // the same way for TelephonyCallback above, so matching that here
        // rather than assuming this project's minSdk is 26+.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes)
                .build()
            focusRequest = request
            manager.requestAudioFocus(request)
        } else {
            @Suppress("DEPRECATION")
            val listener = AudioManager.OnAudioFocusChangeListener { }
            legacyFocusListener = listener
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(
                listener,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
            )
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager?.abandonAudioFocusRequest(it) }
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            legacyFocusListener?.let { audioManager?.abandonAudioFocus(it) }
            legacyFocusListener = null
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Azan Service",
                NotificationManager.IMPORTANCE_HIGH
            )
            // FIXED (Battery/CPU #8): a channel created at IMPORTANCE_HIGH
            // plays Android's default notification sound the moment the
            // notification posts, unless told not to — so starting the
            // actual azan recitation used to be preceded by a stray
            // system "ding" every single time. This notification's whole
            // purpose is to accompany audio that's already playing
            // through the MediaPlayer above; it was never meant to make
            // its own sound.
            channel.setSound(null, null)
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    fun stopAzan() {
        mediaPlayer?.let {
            // FIXED (Battery/CPU #8): stop() is only valid to call from a
            // handful of MediaPlayer states (Started/Paused/...) — from
            // others, notably Error, it throws IllegalStateException
            // rather than just being a no-op. Without this try/catch, a
            // player that had errored out (see setOnErrorListener above)
            // could throw here and skip release() entirely below it,
            // leaking the player's native resources on top of whatever
            // crashed the call in the first place.
            try {
                if (it.isPlayingSafely()) it.stop()
            } catch (e: IllegalStateException) {
                e.printStackTrace()
            }
            it.release()
        }
        mediaPlayer = null
        shouldResumeAfterCall = false
        abandonAudioFocus()
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

// FIXED (Battery/CPU #8): MediaPlayer.isPlaying() is documented to throw
// IllegalStateException in some states (notably Error) instead of just
// returning false, unlike almost every other "is it doing X" check in the
// Android SDK — every isPlaying call site in this file goes through this
// instead of repeating the same try/catch at each one.
private fun MediaPlayer.isPlayingSafely(): Boolean {
    return try {
        isPlaying
    } catch (e: IllegalStateException) {
        false
    }
}