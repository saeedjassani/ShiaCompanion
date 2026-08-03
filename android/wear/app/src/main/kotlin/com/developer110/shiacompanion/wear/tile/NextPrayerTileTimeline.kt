package com.developer110.shiacompanion.wear.tile

import com.developer110.shiacompanion.wear.PrayerScheduleEntry

/** How many prayers to lay out ahead. Eight days of data, capped at a few days of entries. */
internal const val TIMELINE_ENTRIES = 12

/** One timeline entry: [prayer] is what the tile shows between [startMillis] and [endMillis]. */
internal data class TileWindow(
    val prayer: PrayerScheduleEntry,
    val startMillis: Long,
    val endMillis: Long,
)

/**
 * Slices the upcoming prayers into contiguous windows, each ending when its prayer starts.
 *
 * Entry N shows the prayer it ends on, so the renderer always has a valid entry for "the
 * next prayer" without asking the app again — which is what lets the tile roll over with
 * the phone out of range.
 */
internal fun tileWindows(
    upcoming: List<PrayerScheduleEntry>,
    nowMillis: Long,
    limit: Int = TIMELINE_ENTRIES,
): List<TileWindow> {
    var start = nowMillis
    return upcoming
        .asSequence()
        .filter { it.epochMillis > nowMillis }
        .take(limit)
        .map { prayer ->
            TileWindow(prayer = prayer, startMillis = start, endMillis = prayer.epochMillis)
                .also { start = prayer.epochMillis }
        }
        .toList()
}
