package com.developer110.shiacompanion.wear.data

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.DataMap
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await

/** Splits a snapshot DataMap into its string values and its timestamp. */
fun DataMap.toSnapshotValues(): Pair<Map<String, String>, Long?> {
    val values = WatchDataKeys.strings
        .filter { containsKey(it) }
        .associateWith { getString(it).orEmpty() }
    val updatedAt = if (containsKey(WatchDataKeys.UPDATED_AT)) getLong(WatchDataKeys.UPDATED_AT) else null
    return values to updatedAt
}

/** Why the last pull from the phone came back empty-handed. */
enum class SyncProblem {
    /** No connected phone has Shia Companion installed (or it predates watch support). */
    PHONE_APP_MISSING,
    /** The phone is out of reach, or the Data Layer refused. */
    UNREACHABLE,
}

/**
 * The watch app's side of talking to the phone, while it is open: catching
 * up on a snapshot the listener service may have missed, and asking the
 * phone for a fresh one.
 */
class PhoneLink(context: Context) {
    private val appContext = context.applicationContext
    private val repository = SnapshotRepository.get(appContext)

    private val _isRequesting = MutableStateFlow(false)
    val isRequesting: StateFlow<Boolean> = _isRequesting.asStateFlow()

    private val _problem = MutableStateFlow<SyncProblem?>(null)
    val problem: StateFlow<SyncProblem?> = _problem.asStateFlow()

    /**
     * Reads the snapshot DataItem already synced to this watch. The Data Layer
     * keeps it on the watch whether or not the listener ran, so this recovers
     * from a listener that was killed mid-delivery or an app data wipe.
     */
    suspend fun catchUp() {
        try {
            val buffer = Wearable.getDataClient(appContext).dataItems.await()
            try {
                buffer
                    .filter { it.uri.path == WearProtocol.SNAPSHOT_PATH }
                    .map { DataMapItem.fromDataItem(it).dataMap.toSnapshotValues() }
                    .maxByOrNull { it.second ?: 0L }
                    ?.let { (values, updatedAt) ->
                        val known = repository.current.updatedAt?.toEpochMilli() ?: 0L
                        if ((updatedAt ?: Long.MAX_VALUE) > known) repository.apply(values, updatedAt)
                    }
            } finally {
                buffer.release()
            }
        } catch (error: Exception) {
            Log.w(TAG, "Could not read synced data items", error)
        }
    }

    /**
     * Asks every reachable phone with the app to re-send its snapshot. The
     * answer arrives through [SnapshotListenerService] like any other sync.
     */
    suspend fun requestSnapshot() {
        if (_isRequesting.value) return
        _isRequesting.value = true
        try {
            val nodes = Wearable.getCapabilityClient(appContext)
                .getCapability(WearProtocol.PHONE_CAPABILITY, CapabilityClient.FILTER_REACHABLE)
                .await()
                .nodes
            if (nodes.isEmpty()) {
                _problem.value = if (hasAnyPhoneApp()) SyncProblem.UNREACHABLE else SyncProblem.PHONE_APP_MISSING
                return
            }
            val messages = Wearable.getMessageClient(appContext)
            nodes.forEach { node ->
                messages.sendMessage(node.id, WearProtocol.REQUEST_SNAPSHOT_PATH, ByteArray(0)).await()
            }
            _problem.value = null
        } catch (error: Exception) {
            Log.w(TAG, "Snapshot request failed", error)
            _problem.value = SyncProblem.UNREACHABLE
        } finally {
            _isRequesting.value = false
        }
    }

    private suspend fun hasAnyPhoneApp(): Boolean = try {
        Wearable.getCapabilityClient(appContext)
            .getCapability(WearProtocol.PHONE_CAPABILITY, CapabilityClient.FILTER_ALL)
            .await()
            .nodes
            .isNotEmpty()
    } catch (_: Exception) {
        false
    }

    private companion object {
        const val TAG = "PhoneLink"
    }
}
