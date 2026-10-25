package com.developer110.shiacompanion.wear

import com.google.android.gms.wearable.CapabilityInfo
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Answers the Wear app with the app closed: when it opens and asks for the
 * snapshot, and when it is first installed on a watch (its capability
 * appears), so a new watch has prayer times without the phone app being
 * opened first.
 */
class PhoneWearListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path == WearSync.REQUEST_SNAPSHOT_PATH) {
            WearSync.pushSoon(this, force = true)
        }
    }

    override fun onCapabilityChanged(capabilityInfo: CapabilityInfo) {
        if (capabilityInfo.name == WearSync.WEAR_CAPABILITY && capabilityInfo.nodes.isNotEmpty()) {
            WearSync.pushSoon(this, force = true)
        }
    }
}
