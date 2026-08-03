package com.developer110.shiacompanion.wear

/**
 * What the watch screen shows, derived from the stored snapshot and the watch's own clock.
 *
 * Kept apart from the composables so the derivation — which is where the interesting
 * decisions live — can be tested without rendering anything.
 */
data class PrayerUiState(
    val status: SyncStatus,
    val location: String,
    val nextPrayer: PrayerScheduleEntry?,
    val prayers: List<PrayerEntry>,
    val lastSyncedAtMillis: Long?,
)

enum class SyncStatus {
    /** The phone has never sent a snapshot. */
    WAITING_FOR_PHONE,

    /** Synced, but the phone app has no location saved yet. */
    NEEDS_LOCATION,
    LOADED,
}

fun PrayerDataStore.uiState(nowMillis: Long = System.currentTimeMillis()): PrayerUiState {
    val status = when {
        !hasSyncedData -> SyncStatus.WAITING_FOR_PHONE
        !hasPrayerTimes -> SyncStatus.NEEDS_LOCATION
        else -> SyncStatus.LOADED
    }

    return PrayerUiState(
        status = status,
        location = location,
        // The next prayer is worth showing even in the placeholder states, since a
        // schedule that outlives a cleared location is still correct.
        nextPrayer = nextPrayer(nowMillis),
        prayers = if (status == SyncStatus.LOADED) dailyPrayers(nowMillis) else emptyList(),
        lastSyncedAtMillis = lastSyncedAtMillis,
    )
}
