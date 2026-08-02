package com.developer110.shiacompanion.wear

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Receives prayer snapshots pushed from the phone.
 *
 * The watch has its own storage, so the data layer is the only way prayer data gets here.
 * The phone's snapshot reaches the watch three ways, so it stays current whether or not
 * the two are connected at the time:
 *   * a data item — latest-only, replicated in the background, and re-delivered as soon
 *     as the watch comes back into range ([PrayerSyncListenerService]).
 *   * [refreshFromSyncedData] — the copy already replicated to this watch, read on launch
 *     so the app never waits on the phone to render.
 *   * [requestSnapshot] — an explicit pull that wakes the phone app's listener service.
 */
object PhoneSyncManager {
    private const val TAG = "PhoneSyncManager"

    private val _isRequesting = MutableStateFlow(false)

    /** `true` while a snapshot request to the phone is in flight. */
    val isRequesting: StateFlow<Boolean> = _isRequesting.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)

    /** Set when the last pull failed, so the UI can explain what went wrong. */
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    private val _revision = MutableStateFlow(0L)

    /** Bumped every time the stored snapshot changes, to nudge the UI into re-reading it. */
    val revision: StateFlow<Long> = _revision.asStateFlow()

    /**
     * Applies the snapshot Play services has already replicated to this watch.
     *
     * Data items survive reboots and app restarts, so replaying them on every launch is
     * what makes the app render instantly — and keeps it working with the phone out of
     * range entirely, since the snapshot covers eight days.
     */
    fun refreshFromSyncedData(context: Context) {
        val appContext = context.applicationContext
        Wearable.getDataClient(appContext).dataItems
            .addOnSuccessListener { buffer ->
                try {
                    buffer
                        .firstOrNull { it.uri.path == WearSyncPaths.PRAYER_SNAPSHOT }
                        ?.let { ingest(appContext, DataMapItem.fromDataItem(it).dataMap) }
                } finally {
                    buffer.release()
                }
            }
            .addOnFailureListener { error ->
                Log.w(TAG, "Unable to read the synced prayer snapshot", error)
            }
    }

    /**
     * Asks the phone for a fresh snapshot. Reaching out also starts the phone app's
     * listener service, so this works even when the user has not opened it recently.
     */
    fun requestSnapshot(context: Context) {
        val appContext = context.applicationContext
        _isRequesting.value = true

        Wearable.getNodeClient(appContext).connectedNodes
            .addOnSuccessListener { nodes ->
                if (nodes.isEmpty()) {
                    finishRequest(appContext.getString(R.string.error_phone_not_connected))
                    return@addOnSuccessListener
                }

                var pending = nodes.size
                var delivered = false
                nodes.forEach { node ->
                    Wearable.getMessageClient(appContext)
                        .sendMessage(node.id, WearSyncPaths.REQUEST_SNAPSHOT, ByteArray(0))
                        .addOnSuccessListener { delivered = true }
                        .addOnCompleteListener {
                            pending -= 1
                            if (pending == 0) {
                                finishRequest(
                                    if (delivered) {
                                        null
                                    } else {
                                        appContext.getString(R.string.error_phone_unreachable)
                                    }
                                )
                            }
                        }
                }
            }
            .addOnFailureListener { error ->
                Log.w(TAG, "Unable to reach the phone", error)
                finishRequest(
                    error.localizedMessage
                        ?: appContext.getString(R.string.error_phone_not_connected)
                )
            }
    }

    /** Stores a payload from the phone and refreshes everything rendering it. */
    fun ingest(context: Context, dataMap: DataMap) {
        val payload = buildMap<String, Any?> {
            for (key in WearDataKeys.STRING_KEYS) {
                if (dataMap.containsKey(key)) put(key, dataMap.getString(key))
            }
            if (dataMap.containsKey(WearDataKeys.UPDATED_AT)) {
                put(WearDataKeys.UPDATED_AT, dataMap.getLong(WearDataKeys.UPDATED_AT))
            }
        }
        if (payload.isEmpty()) return

        val appContext = context.applicationContext
        PrayerDataStore.get(appContext).apply(payload)
        _lastError.value = null
        _revision.value = _revision.value + 1

        PrayerSurfaces.refresh(appContext)
        PrayerSurfaces.scheduleNextRefresh(appContext)
    }

    private fun finishRequest(error: String?) {
        _isRequesting.value = false
        _lastError.value = error
    }
}
