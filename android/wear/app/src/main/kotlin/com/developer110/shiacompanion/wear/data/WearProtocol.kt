package com.developer110.shiacompanion.wear.data

/**
 * The Data Layer contract between the phone app and the watch app. The phone
 * side keeps its own copy of these strings in
 * android/app/.../wear/WearSync.kt - change both together.
 */
object WearProtocol {
    /** The DataItem holding the latest snapshot. Latest-only, like WatchConnectivity's applicationContext. */
    const val SNAPSHOT_PATH = "/shia_companion/snapshot"

    /** Watch -> phone message asking for the snapshot to be re-sent now. */
    const val REQUEST_SNAPSHOT_PATH = "/shia_companion/request_snapshot"

    /** Advertised by the watch app (res/values/wear.xml); the phone only syncs to nodes that have it. */
    const val WEAR_CAPABILITY = "shia_companion_wear_app"

    /** Advertised by the phone app, so the watch can tell "phone app missing" from "phone out of reach". */
    const val PHONE_CAPABILITY = "shia_companion_phone_app"
}
