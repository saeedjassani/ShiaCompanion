package com.developer110.shiacompanion.wear

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService

/**
 * Applies snapshots the phone publishes, whether or not the watch app is running.
 *
 * Play services starts this service when a data item lands, which is what keeps the tile
 * and the complication current without anyone opening the app.
 */
class PrayerSyncListenerService : WearableListenerService() {
    override fun onDataChanged(dataEvents: DataEventBuffer) {
        for (event in dataEvents) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            if (event.dataItem.uri.path != WearSyncPaths.PRAYER_SNAPSHOT) continue

            PhoneSyncManager.ingest(this, DataMapItem.fromDataItem(event.dataItem).dataMap)
        }
    }
}
