package com.developer110.shiacompanion.wear.data

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService

/**
 * Receives the phone's snapshot whenever it changes, even with the watch app
 * closed, so the tile and complications stay current without it being opened.
 */
class SnapshotListenerService : WearableListenerService() {
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        val repository = SnapshotRepository.get(this)
        dataEvents.forEach { event ->
            if (event.type != DataEvent.TYPE_CHANGED) return@forEach
            val item = event.dataItem
            if (item.uri.path != WearProtocol.SNAPSHOT_PATH) return@forEach
            val (values, updatedAt) = DataMapItem.fromDataItem(item).dataMap.toSnapshotValues()
            repository.apply(values, updatedAt)
        }
    }
}
