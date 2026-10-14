package com.developer110.shiacompanion.azan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import com.developer110.shiacompanion.R
import java.io.File

/** What to play, and how the notification should describe it. */
data class AzanPlayRequest(
    val prayerName: String,
    val playingTitle: String,
    val pausedTitle: String,
    val customFilePath: String?,
) {
    fun writeTo(intent: Intent): Intent = intent
        .putExtra(EXTRA_PRAYER, prayerName)
        .putExtra(EXTRA_TITLE, playingTitle)
        .putExtra(EXTRA_PAUSED_TITLE, pausedTitle)
        .putExtra(EXTRA_CUSTOM, customFilePath)

    companion object {
        private const val EXTRA_PRAYER = "prayer"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_PAUSED_TITLE = "pausedTitle"
        private const val EXTRA_CUSTOM = "custom"

        fun from(intent: Intent): AzanPlayRequest? {
            val prayer = intent.getStringExtra(EXTRA_PRAYER) ?: return null
            val title = intent.getStringExtra(EXTRA_TITLE) ?: return null
            return AzanPlayRequest(
                prayerName = prayer,
                playingTitle = title,
                pausedTitle = intent.getStringExtra(EXTRA_PAUSED_TITLE) ?: title,
                customFilePath = intent.getStringExtra(EXTRA_CUSTOM),
            )
        }
    }
}

/** Whether an Azan is under way, as the app's banner shows it. */
data class AzanState(val active: Boolean, val paused: Boolean, val prayerName: String?) {
    fun toMap(): Map<String, Any?> =
        mapOf("playing" to active, "paused" to paused, "prayerName" to prayerName)

    companion object {
        val IDLE = AzanState(active = false, paused = false, prayerName = null)
    }
}

/**
 * Plays the Azan as a foreground media-playback service: a real player with
 * audio focus and a notification to pause or stop it, which keeps going with
 * the screen locked and the app closed.
 *
 * Started by [AzanAlarmReceiver] at prayer time and by the app (a tap on a
 * prayer notification, a preview, Play Azan). One Azan at a time: a request
 * while one is audible is ignored, and one while it is paused replaces it.
 */
class AzanPlayerService : Service(), AudioManager.OnAudioFocusChangeListener {

    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var request: AzanPlayRequest? = null
    private var usingCustomFile = false
    private var prepared = false
    private var paused = false
    private var pausedForFocus = false
    private var waitingForFocus = false
    private var focusRequest: AudioFocusRequest? = null
    private val stopAfterLongPause = Runnable { finish("paused too long") }
    private val stopWithoutFocus = Runnable { finish("audio focus didn't come back in time") }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        current = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> handlePlay(intent)
            ACTION_PAUSE -> pause()
            ACTION_RESUME -> resume()
            ACTION_STOP -> finish("stopped")
            else -> if (request == null) stopSelf()
        }
        // Never restarted by Android after being killed: an Azan replayed
        // minutes later, out of nowhere, is worse than one cut short.
        return START_NOT_STICKY
    }

    private fun handlePlay(intent: Intent) {
        val incoming = AzanPlayRequest.from(intent)
        val playingNow = request != null && !paused
        // Every startForegroundService() must be answered with
        // startForeground() within seconds, or Android kills the app - even
        // for a request this then ignores.
        val shown = if (playingNow) request!! else incoming
        if (shown == null) {
            AzanLog.error(TAG, "Play request without a prayer; ignoring")
            if (request == null) finish("bad request") else AzanWakeLock.release()
            return
        }
        if (!enterForeground(shown, paused = false)) return
        if (playingNow) {
            AzanLog.info(TAG, "An Azan is already playing; ignoring the request for ${incoming?.prayerName}")
            AzanWakeLock.release()
            return
        }
        start(incoming!!)
    }

    private fun start(next: AzanPlayRequest) {
        releasePlayer()
        handler.removeCallbacks(stopAfterLongPause)
        handler.removeCallbacks(stopWithoutFocus)
        request = next
        paused = false
        pausedForFocus = false
        waitingForFocus = false
        prepared = false
        usingCustomFile = false
        val media = MediaPlayer()
        player = media
        media.setAudioAttributes(AUDIO_ATTRIBUTES)
        media.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
        media.setOnPreparedListener { onPrepared(it) }
        media.setOnCompletionListener { if (it === player) finish("completed") }
        media.setOnErrorListener { mp, what, extra ->
            if (mp === player) onPlaybackError("MediaPlayer error $what/$extra")
            true
        }
        try {
            usingCustomFile = setSource(media, next.customFilePath)
            media.prepareAsync()
        } catch (e: Exception) {
            onPlaybackError("Could not open the Azan audio: $e")
        }
        notifyStateChanged()
    }

    /** Sets [media]'s source and says whether it is the custom file. */
    private fun setSource(media: MediaPlayer, customFilePath: String?): Boolean {
        // The prayer notification is silent for Full Azan and Custom Audio
        // (this is the sound), so a custom file that has since disappeared
        // must not leave the reader with nothing: the bundled Azan plays.
        if (customFilePath != null) {
            if (File(customFilePath).canRead()) {
                try {
                    media.setDataSource(customFilePath)
                    return true
                } catch (e: Exception) {
                    AzanLog.warn(TAG, "Custom Azan file unplayable, using the bundled one: $e")
                    media.reset()
                    media.setAudioAttributes(AUDIO_ATTRIBUTES)
                    media.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
                }
            } else {
                AzanLog.warn(TAG, "Custom Azan file missing, using the bundled one")
            }
        }
        setBundledSource(media)
        return false
    }

    private fun setBundledSource(media: MediaPlayer) {
        try {
            assets.openFd(BUNDLED_AZAN_ASSET).use {
                media.setDataSource(it.fileDescriptor, it.startOffset, it.length)
            }
        } catch (e: java.io.FileNotFoundException) {
            // openFd only works for an asset stored uncompressed; if the
            // build ever compresses it, play a copy instead.
            val copy = File(cacheDir, "full_azan.mp3")
            if (!copy.exists()) {
                assets.open(BUNDLED_AZAN_ASSET).use { input ->
                    copy.outputStream().use { input.copyTo(it) }
                }
            }
            media.setDataSource(copy.path)
        }
    }

    private fun onPrepared(media: MediaPlayer) {
        if (media !== player) return
        prepared = true
        if (requestFocus()) {
            media.start()
            AzanLog.info(TAG, "Azan playing for ${request?.prayerName}")
        } else {
            // A call is under way: wait for it to end rather than play over it.
            waitForFocus()
            AzanLog.info(TAG, "Azan waiting for audio focus")
        }
        AzanWakeLock.release()
    }

    private fun onPlaybackError(message: String) {
        val failed = request
        if (failed != null && usingCustomFile) {
            AzanLog.warn(TAG, "$message; retrying with the bundled Azan")
            start(failed.copy(customFilePath = null))
            return
        }
        AzanLog.error(TAG, message)
        finish("error")
    }

    private fun pause() {
        val media = player ?: return
        if (paused) return
        if (prepared && media.isPlaying) media.pause()
        waitingForFocus = false
        paused = true
        handler.removeCallbacks(stopAfterLongPause)
        handler.removeCallbacks(stopWithoutFocus)
        handler.postDelayed(stopAfterLongPause, MAX_PAUSE_MILLIS)
        refreshNotification()
        notifyStateChanged()
    }

    private fun resume() {
        val media = player ?: return
        if (!paused) return
        paused = false
        pausedForFocus = false
        handler.removeCallbacks(stopAfterLongPause)
        handler.removeCallbacks(stopWithoutFocus)
        if (prepared) {
            if (requestFocus()) media.start() else waitForFocus()
        }
        refreshNotification()
        notifyStateChanged()
    }

    override fun onAudioFocusChange(change: Int) {
        val media = player ?: return
        when (change) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                handler.removeCallbacks(stopWithoutFocus)
                if (waitingForFocus && !paused && prepared) {
                    waitingForFocus = false
                    media.start()
                } else if (pausedForFocus) {
                    resume()
                }
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                // A call or another app's short sound: back after it - but
                // not long after, when the Azan would no longer be on time.
                if (!paused) {
                    pause()
                    pausedForFocus = true
                    handler.removeCallbacks(stopAfterLongPause)
                    handler.postDelayed(stopWithoutFocus, AzanScheduleRules.LATE_LIMIT_MILLIS)
                }
            }
            AudioManager.AUDIOFOCUS_LOSS -> pause()
        }
    }

    /**
     * Waits for audio focus (a call, usually) to come back - for as long as
     * an alarm may be late, after which the Azan would no longer be on time.
     */
    private fun waitForFocus() {
        waitingForFocus = true
        handler.removeCallbacks(stopWithoutFocus)
        handler.postDelayed(stopWithoutFocus, AzanScheduleRules.LATE_LIMIT_MILLIS)
    }

    private fun requestFocus(): Boolean {
        val audioManager = getSystemService(AudioManager::class.java)
        val focus = focusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(AUDIO_ATTRIBUTES)
            .setAcceptsDelayedFocusGain(true)
            .setOnAudioFocusChangeListener(this, handler)
            .build()
            .also { focusRequest = it }
        return audioManager.requestAudioFocus(focus) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun finish(reason: String) {
        AzanLog.info(TAG, "Azan finished: $reason")
        handler.removeCallbacks(stopAfterLongPause)
        handler.removeCallbacks(stopWithoutFocus)
        releasePlayer()
        focusRequest?.let { getSystemService(AudioManager::class.java).abandonAudioFocusRequest(it) }
        focusRequest = null
        request = null
        paused = false
        pausedForFocus = false
        waitingForFocus = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        AzanWakeLock.release()
        notifyStateChanged()
    }

    private fun releasePlayer() {
        val media = player ?: return
        player = null
        prepared = false
        try {
            media.release()
        } catch (e: Exception) {
            AzanLog.warn(TAG, "MediaPlayer release failed: $e")
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(stopAfterLongPause)
        handler.removeCallbacks(stopWithoutFocus)
        releasePlayer()
        focusRequest?.let { getSystemService(AudioManager::class.java).abandonAudioFocusRequest(it) }
        if (current === this) current = null
        AzanWakeLock.release()
        notifyStateChanged()
        super.onDestroy()
    }

    private fun enterForeground(shown: AzanPlayRequest, paused: Boolean): Boolean = try {
        startForeground(
            NOTIFICATION_ID,
            buildNotification(shown, paused),
            ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
        )
        true
    } catch (e: Exception) {
        AzanLog.error(TAG, "Could not enter the foreground for the Azan", e)
        finish("no foreground")
        false
    }

    private fun refreshNotification() {
        val shown = request ?: return
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, buildNotification(shown, paused))
    }

    private fun buildNotification(shown: AzanPlayRequest, paused: Boolean): Notification {
        val labels = AzanSchedule.labels(this) ?: fallbackLabels()
        ensureChannel(labels.channelName)
        val toggle = if (paused) {
            NotificationCompat.Action(0, labels.resume, actionIntent(ACTION_RESUME))
        } else {
            NotificationCompat.Action(0, labels.pause, actionIntent(ACTION_PAUSE))
        }
        // This, not the app, is what someone sees when the Azan starts
        // unprompted - often with the phone locked - so the title says what
        // is happening and pause/stop are right there.
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(if (paused) shown.pausedTitle else shown.playingTitle)
            .setContentIntent(AzanSchedule.launchAppIntent(this))
            .setDeleteIntent(actionIntent(ACTION_STOP))
            .setOngoing(!paused)
            .setSilent(true)
            .setShowWhen(false)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_TRANSPORT)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .addAction(toggle)
            .addAction(NotificationCompat.Action(0, labels.stop, actionIntent(ACTION_STOP)))
            .build()
    }

    private fun ensureChannel(name: String) {
        // Same id audio_service created this channel under, so an update
        // doesn't leave a second "Azan playback" entry in the app's settings.
        // Re-creating an existing channel only updates its name.
        val channel = NotificationChannel(CHANNEL_ID, name, NotificationManager.IMPORTANCE_LOW).apply {
            setSound(null, null)
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun fallbackLabels() = AzanLabels(
        pause = getString(R.string.azan_pause_fallback),
        resume = getString(R.string.azan_resume_fallback),
        stop = getString(R.string.azan_stop_fallback),
        channelName = getString(R.string.azan_channel_fallback),
    )

    private fun actionIntent(action: String): PendingIntent = PendingIntent.getService(
        this,
        action.hashCode(),
        Intent(this, AzanPlayerService::class.java).setAction(action),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun state() = request?.let {
        AzanState(active = true, paused = paused, prayerName = it.prayerName)
    } ?: AzanState.IDLE

    companion object {
        private const val TAG = "AzanPlayer"
        const val ACTION_PLAY = "com.developer110.shiacompanion.azan.PLAY"
        const val ACTION_PAUSE = "com.developer110.shiacompanion.azan.PAUSE"
        const val ACTION_RESUME = "com.developer110.shiacompanion.azan.RESUME"
        const val ACTION_STOP = "com.developer110.shiacompanion.azan.STOP"
        const val CHANNEL_ID = "com.developer110.shia_companion.azan"
        private const val NOTIFICATION_ID = 1_786_001
        private const val BUNDLED_AZAN_ASSET = "flutter_assets/assets/sounds/full_azan.mp3"

        /** A paused Azan is let go after this, rather than holding the service forever. */
        private const val MAX_PAUSE_MILLIS = 30 * 60 * 1000L

        private val AUDIO_ATTRIBUTES: AudioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()

        @Volatile
        private var current: AzanPlayerService? = null

        /** Told on the main thread whenever [state] may have changed. */
        var onStateChanged: ((AzanState) -> Unit)? = null

        fun state(): AzanState = current?.state() ?: AzanState.IDLE

        /**
         * Starts [request]. From an alarm, a wake lock bridges the gap until
         * the player holds its own, so the phone can't sleep in between.
         */
        fun play(context: Context, request: AzanPlayRequest, fromAlarm: Boolean) {
            if (fromAlarm) AzanWakeLock.acquire(context)
            val intent = request.writeTo(
                Intent(context, AzanPlayerService::class.java).setAction(ACTION_PLAY),
            )
            try {
                context.startForegroundService(intent)
            } catch (e: Exception) {
                // Android 12+ refuses this from the background unless the
                // trigger was an exact alarm - so this means the alarm wasn't
                // one, or the OEM blocked it. The prayer notification still
                // offers a tap to play.
                AzanWakeLock.release()
                AzanLog.error(TAG, "Could not start Azan playback (fromAlarm=$fromAlarm)", e)
            }
        }

        fun pause() = current?.pause()
        fun resume() = current?.resume()
        fun stop() = current?.finish("stopped from the app")

        private fun notifyStateChanged() {
            val listener = onStateChanged ?: return
            listener(state())
        }
    }

    private fun notifyStateChanged() = Companion.notifyStateChanged()
}

/**
 * Keeps the CPU awake from the moment an alarm fires until the player holds
 * its own wake lock: Android only guarantees the alarm's for the length of
 * onReceive.
 */
internal object AzanWakeLock {
    private const val TIMEOUT_MILLIS = 60_000L
    private var lock: PowerManager.WakeLock? = null

    @Synchronized
    fun acquire(context: Context) {
        if (lock?.isHeld == true) return
        lock = context.getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ShiaCompanion:AzanStart")
            .apply {
                setReferenceCounted(false)
                acquire(TIMEOUT_MILLIS)
            }
    }

    @Synchronized
    fun release() {
        lock?.takeIf { it.isHeld }?.release()
        lock = null
    }
}
