package com.developer110.shiacompanion.wear.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import java.time.Instant
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * The last snapshot received from the phone, kept on the watch so the app,
 * the tile and the complications all work with the phone out of reach.
 *
 * One per process: the Data Layer listener service and the activity write
 * through the same instance, so an open screen sees a sync the moment it
 * lands.
 */
class SnapshotRepository private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val prefs: SharedPreferences =
        appContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    private val _snapshot = MutableStateFlow(readFromDisk())
    val snapshot: StateFlow<WatchSnapshot> = _snapshot.asStateFlow()

    val current: WatchSnapshot get() = _snapshot.value

    /**
     * Merges a payload from the phone. Only known keys are written, so a
     * malformed or oversized payload can't pollute storage. Returns whether
     * anything was written.
     */
    fun apply(values: Map<String, String>, updatedAtMillis: Long?): Boolean {
        val known = WatchDataKeys.strings.filter { it in values }
        if (known.isEmpty()) return false
        prefs.edit {
            known.forEach { putString(it, values.getValue(it)) }
            // A payload without a timestamp still counts as a sync.
            putLong(WatchDataKeys.UPDATED_AT, updatedAtMillis ?: System.currentTimeMillis())
        }
        _snapshot.value = readFromDisk()
        SurfaceUpdater.requestAll(appContext)
        return true
    }

    private fun readFromDisk(): WatchSnapshot {
        val values = WatchDataKeys.strings.associateWith { prefs.getString(it, null) }
            .filterValues { it != null }
            .mapValues { it.value!! }
        val millis = prefs.getLong(WatchDataKeys.UPDATED_AT, 0L)
        return WatchSnapshot(values, if (millis > 0) Instant.ofEpochMilli(millis) else null)
    }

    companion object {
        private const val PREFERENCES_NAME = "shia_companion_wear_snapshot"

        @Volatile
        private var instance: SnapshotRepository? = null

        fun get(context: Context): SnapshotRepository =
            instance ?: synchronized(this) {
                instance ?: SnapshotRepository(context).also { instance = it }
            }
    }
}
