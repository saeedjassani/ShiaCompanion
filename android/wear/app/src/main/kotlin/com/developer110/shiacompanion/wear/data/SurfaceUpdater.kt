package com.developer110.shiacompanion.wear.data

import android.content.ComponentName
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.wear.tiles.TileService
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester
import com.developer110.shiacompanion.wear.complication.HijriDateComplicationService
import com.developer110.shiacompanion.wear.complication.NextPrayerComplicationService
import com.developer110.shiacompanion.wear.complication.TasbeehComplicationService
import com.developer110.shiacompanion.wear.tile.PrayerTileService

/**
 * Tells the tile and the complications that what they show has changed.
 * Both are rendered by the system from our services, so they only redraw when
 * asked to (or when their own timeline moves on).
 */
object SurfaceUpdater {
    /**
     * Long enough that a burst of counting collapses into one update: the
     * system throttles a data source that asks too often, and only the value
     * the count stops on is worth drawing.
     */
    private const val COUNTER_DEBOUNCE_MS = 2_000L

    private val handler by lazy { Handler(Looper.getMainLooper()) }
    private var pendingCounter: Runnable? = null

    fun requestAll(context: Context) {
        val appContext = context.applicationContext
        runCatching { TileService.getUpdater(appContext).requestUpdate(PrayerTileService::class.java) }
            .onFailure { Log.w(TAG, "Tile update request failed", it) }
        requestComplications(appContext, NextPrayerComplicationService::class.java)
        requestComplications(appContext, HijriDateComplicationService::class.java)
    }

    fun requestCounter(context: Context) {
        val appContext = context.applicationContext
        pendingCounter?.let(handler::removeCallbacks)
        val work = Runnable {
            pendingCounter = null
            requestComplications(appContext, TasbeehComplicationService::class.java)
        }
        pendingCounter = work
        handler.postDelayed(work, COUNTER_DEBOUNCE_MS)
    }

    /** Pushes a pending counter update now, e.g. as the app leaves the foreground. */
    fun flushCounter(context: Context) {
        val work = pendingCounter ?: return
        handler.removeCallbacks(work)
        pendingCounter = null
        requestComplications(context.applicationContext, TasbeehComplicationService::class.java)
    }

    private fun requestComplications(context: Context, service: Class<*>) {
        runCatching {
            ComplicationDataSourceUpdateRequester
                .create(context, ComponentName(context, service))
                .requestUpdateAll()
        }.onFailure { Log.w(TAG, "Complication update request failed for ${service.simpleName}", it) }
    }

    private const val TAG = "SurfaceUpdater"
}
