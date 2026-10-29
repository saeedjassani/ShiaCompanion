package com.developer110.shiacompanion.wear.ui

import com.developer110.shiacompanion.wear.data.HijriDay
import com.developer110.shiacompanion.wear.data.IslamicEvent
import com.developer110.shiacompanion.wear.data.PrayerScheduleEntry
import com.developer110.shiacompanion.wear.data.WatchSnapshot
import java.time.Instant
import java.time.ZoneId

/** Which of its three faces the home screen shows. */
enum class HomeMode {
    /** The phone has never sent a snapshot. */
    WAITING_FOR_PHONE,
    /** Synced, but the phone app has no location saved yet. */
    NEEDS_LOCATION,
    LOADED,
}

/** One row of the prayer list; [dayBreak] names the day where the list crosses into it. */
data class PrayerRow(val entry: PrayerScheduleEntry, val dayBreak: String?)

data class HomeState(
    val mode: HomeMode,
    val location: String,
    val next: PrayerScheduleEntry?,
    val rows: List<PrayerRow>,
    val hijriDay: HijriDay?,
    val nextEvent: IslamicEvent?,
    val lastSync: Instant?,
    /** When this state next changes on its own: the next prayer, or the next hijri day. */
    val nextChange: Instant?,
)

/**
 * Everything the home screen shows, worked out from the snapshot and the
 * time. Kept free of Compose so the rules are unit-tested directly.
 */
fun buildHomeState(snapshot: WatchSnapshot, now: Instant, zone: ZoneId): HomeState {
    val mode = when {
        !snapshot.hasSyncedData -> HomeMode.WAITING_FOR_PHONE
        !snapshot.hasPrayerTimes -> HomeMode.NEEDS_LOCATION
        else -> HomeMode.LOADED
    }
    val upcoming = if (mode == HomeMode.LOADED) snapshot.upcomingPrayers(now) else emptyList()
    val next = upcoming.firstOrNull()
    // The first upcoming time is already the "Up Next" banner, so the list
    // starts with the one after it - on a screen this small, saying the
    // immediate prayer twice costs a whole row.
    val listed = upcoming.drop(1)
    fun dayLabel(entry: PrayerScheduleEntry): String? =
        entry.dateLabel.takeUnless { entry.time.atZone(zone).toLocalDate() == now.atZone(zone).toLocalDate() }
    val rows = listed.mapIndexed { index, entry ->
        val label = dayLabel(entry)
        val before = if (index == 0) next else listed[index - 1]
        // Named once, where the list crosses into the day, rather than on
        // every row of it. When the banner itself is already tomorrow's, it
        // has said so, and the list carries on without repeating it.
        PrayerRow(entry, label?.takeIf { before == null || dayLabel(before) != it })
    }
    val hijriDay = snapshot.hijriDay(now)
    return HomeState(
        mode = mode,
        location = snapshot.location,
        next = next,
        rows = rows,
        hijriDay = hijriDay,
        nextEvent = snapshot.upcomingEvents(now, zone, limit = 1).firstOrNull(),
        lastSync = snapshot.updatedAt,
        nextChange = snapshot.transitionsAfter(now).firstOrNull(),
    )
}
