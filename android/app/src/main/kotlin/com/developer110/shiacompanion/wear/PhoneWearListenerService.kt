package com.developer110.shiacompanion.wear

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Answers the watch's pull request.
 *
 * The watch app asks for a snapshot every time it opens. Play services starts this
 * service to deliver the message, so the phone replies even when the Flutter app has not
 * been opened in days — the snapshot covers eight days of prayer times, so what the
 * widgets last stored is still useful.
 */
class PhoneWearListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != WearSnapshot.REQUEST_PATH) return

        WearSnapshotPublisher.publish(this, force = true)
    }
}
