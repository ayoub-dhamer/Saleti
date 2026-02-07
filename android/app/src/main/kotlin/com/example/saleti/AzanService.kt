package com.example.saleti

import android.app.Service
import android.content.Intent
import android.media.MediaPlayer
import android.os.IBinder

class AzanService : Service() {

    private var player: MediaPlayer? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        player = MediaPlayer.create(this, R.raw.azan)
        player?.isLooping = false
        player?.start()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        player?.stop()
        player?.release()
        player = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
