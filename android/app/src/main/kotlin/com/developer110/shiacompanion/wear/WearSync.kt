package com.developer110.shiacompanion.wear

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await

/**
 * Sends the home-widget snapshot on to the Wear OS app, the Android
 * counterpart of AppDelegate.m's pushSnapshotToWatch for the Apple Watch.
 *
 * Dormant without a watch: nothing is written to the Data Layer unless a
 * paired watch advertises the Wear app's capability, so a phone with no
 * watch - or a watch without the (not yet published) Wear app - costs one
 * capability lookup and nothing else. See docs/WEAR_OS.md.
 *
 * The paths, capability names and keys must match the Wear app's
 * android/wear/app/.../data/WearProtocol.kt and WatchSnapshot.kt.
 */
object WearSync {
    private const val TAG = "WearSync"
    private const val SNAPSHOT_PATH = "/shia_companion/snapshot"
    const val REQUEST_SNAPSHOT_PATH = "/shia_companion/request_snapshot"
    const val WEAR_CAPABILITY = "shia_companion_wear_app"
    private const val UPDATED_AT_KEY = "sc_watch_updated_at"

    /** Where MainActivity's saveWidgetData writes the snapshot. */
    private const val WIDGET_PREFERENCES = "shia_companion_widgets"

    /** The widget keys the watch reads; the same set the Apple Watch gets. */
    private val snapshotKeys: List<String> = listOf(
        "sc_prayer_location",
        "sc_prayer_schedule",
        "sc_prayer_name",
        "sc_prayer_time",
        "sc_prayer_date",
        "sc_prayer_secondary_name",
        "sc_prayer_secondary_time",
        "sc_daily_prayer_schedule",
        "sc_calendar_days",
        "sc_calendar_events",
    )

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mutex = Mutex()

    /** The content last handed to the Data Layer, to skip re-sending an unchanged snapshot. */
    private var lastSent: Map<String, String>? = null

    /**
     * Pushes the current snapshot in the background. [force] re-sends even an
     * unchanged one - used when the watch asks, since it may have missed it.
     */
    fun pushSoon(context: Context, force: Boolean = false) {
        val appContext = context.applicationContext
        scope.launch { push(appContext, force) }
    }

    suspend fun push(context: Context, force: Boolean = false) = mutex.withLock {
        try {
            if (!hasWatchApp(context)) return@withLock
            val prefs = context.getSharedPreferences(WIDGET_PREFERENCES, Context.MODE_PRIVATE)
            val content = snapshotKeys
                .mapNotNull { key -> prefs.getString(key, null)?.let { key to it } }
                .toMap()
            if (content.isEmpty()) return@withLock
            if (!force && content == lastSent) return@withLock

            val request = PutDataMapRequest.create(SNAPSHOT_PATH).apply {
                content.forEach { (key, value) -> dataMap.putString(key, value) }
                // Always differs, so a forced push reaches the watch even when
                // the content is what it already has, and "Synced" moves on.
                dataMap.putLong(UPDATED_AT_KEY, System.currentTimeMillis())
            }.asPutDataRequest().setUrgent()
            Wearable.getDataClient(context).putDataItem(request).await()
            lastSent = content
        } catch (error: Exception) {
            // No Wear OS app on the phone (ApiException API_UNAVAILABLE), or
            // Play services out of date: the watch simply stays as it was.
            Log.i(TAG, "Watch sync skipped: ${error.message}")
        }
    }

    private suspend fun hasWatchApp(context: Context): Boolean =
        Wearable.getCapabilityClient(context)
            .getCapability(WEAR_CAPABILITY, CapabilityClient.FILTER_ALL)
            .await()
            .nodes
            .isNotEmpty()
}
