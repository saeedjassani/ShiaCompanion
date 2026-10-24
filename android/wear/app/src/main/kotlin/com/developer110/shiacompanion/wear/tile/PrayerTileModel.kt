package com.developer110.shiacompanion.wear.tile

import com.developer110.shiacompanion.wear.data.PrayerScheduleEntry
import com.developer110.shiacompanion.wear.data.WatchSnapshot
import java.time.Instant
import java.time.ZoneId

/** What the tile shows from [start] until [end] (open-ended when null). */
data class PrayerTileEntry(
    val start: Instant,
    val end: Instant?,
    val next: PrayerScheduleEntry?,
    /** The times after [next], as many as fit under it. */
    val after: List<PrayerScheduleEntry>,
    val hijriShort: String?,
)

/**
 * How many entries a tile timeline carries. Each prayer time is a boundary,
 * and a selection of three to five times a day makes this about two days -
 * longer than the phone ever goes between syncs while in use.
 */
const val TILE_TIMELINE_ENTRIES = 12

/** How many times are listed under the next one. */
const val TILE_TIMES_AFTER = 2

/**
 * The tile's timeline: one entry per stretch between prayer times, so the
 * system rolls the tile on to the next prayer by itself, without waking the
 * app. Kept free of the tile APIs so it is unit-tested directly.
 */
fun buildPrayerTileTimeline(snapshot: WatchSnapshot, now: Instant, zone: ZoneId): List<PrayerTileEntry> {
    if (!snapshot.hasPrayerTimes) return listOf(PrayerTileEntry(now, null, null, emptyList(), null))
    val boundaries = listOf(now) + snapshot.prayerSchedule.map { it.time }
        .filter { it.isAfter(now) }
        .take(TILE_TIMELINE_ENTRIES - 1)
    return boundaries.mapIndexed { index, start ->
        val upcoming = snapshot.upcomingPrayers(start, TILE_TIMES_AFTER + 1)
        PrayerTileEntry(
            start = start,
            end = boundaries.getOrNull(index + 1),
            next = upcoming.firstOrNull(),
            after = upcoming.drop(1),
            hijriShort = snapshot.hijriDay(start)?.let { "${it.day} ${it.monthShort}" },
        )
    }
}
