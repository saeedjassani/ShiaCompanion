package com.developer110.shiacompanion.wear.data

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import org.json.JSONArray
import org.json.JSONObject

/**
 * Keys of the snapshot the phone sends, the same ones the Flutter app's
 * `HomeScreenWidgetService` writes for the home-screen widgets.
 *
 * Must stay in step with `WearSync.snapshotKeys` in the phone app
 * (android/app/.../wear/WearSync.kt) and, for parity, with `WatchDataKeys`
 * in the Apple Watch app's PrayerDataStore.swift.
 */
object WatchDataKeys {
    const val PRAYER_LOCATION = "sc_prayer_location"
    const val PRAYER_SCHEDULE = "sc_prayer_schedule"
    const val PRAYER_NAME = "sc_prayer_name"
    const val PRAYER_TIME = "sc_prayer_time"
    const val PRAYER_DATE = "sc_prayer_date"
    const val PRAYER_SECONDARY_NAME = "sc_prayer_secondary_name"
    const val PRAYER_SECONDARY_TIME = "sc_prayer_secondary_time"
    const val DAILY_PRAYER_SCHEDULE = "sc_daily_prayer_schedule"

    /** One JSON entry per day for the hijri date. */
    const val CALENDAR_DAYS = "sc_calendar_days"
    /** The Islamic events coming up, as JSON. */
    const val CALENDAR_EVENTS = "sc_calendar_events"

    /** Epoch millis of the last payload the phone sent. Absent until the first sync. */
    const val UPDATED_AT = "sc_watch_updated_at"

    val strings: List<String> = listOf(
        PRAYER_LOCATION,
        PRAYER_SCHEDULE,
        PRAYER_NAME,
        PRAYER_TIME,
        PRAYER_DATE,
        PRAYER_SECONDARY_NAME,
        PRAYER_SECONDARY_TIME,
        DAILY_PRAYER_SCHEDULE,
        CALENDAR_DAYS,
        CALENDAR_EVENTS,
    )
}

/** One upcoming time from the phone's `sc_prayer_schedule`. */
data class PrayerScheduleEntry(
    val time: Instant,
    val name: String,
    val displayTime: String,
    /** "Today", "Tomorrow" or a short date, in the phone's language. */
    val dateLabel: String,
    val secondaryName: String = "",
    val secondaryTime: String = "",
)

/** One day of the Islamic calendar, as the phone published it. */
data class HijriDay(
    val start: Instant,
    val day: Int,
    val month: String,
    /** "Jum I", "Rab II": for complications, where the full name does not fit. */
    val monthShort: String,
    val year: Int,
    /** Today's event, name first. Empty on most days. */
    val event: String,
    /** [event] with "Hazrat"/"Imam" cut short. */
    val eventShort: String,
    /** "Birth", "Martyrdom", "Death", or empty for an event about no one person. */
    val kind: String,
    /** events.json's colour: 0 mourning, 1 joy, -1 none. */
    val color: Int,
) {
    /** "13 Jumada al-Awwal", for the app's own screens. */
    val dateLine: String get() = "$day $month"
    /** "13 Jum I 1448", for complications. */
    val shortDateLine: String get() = "$day $monthShort $year"
}

data class IslamicEvent(
    val start: Instant,
    val day: Int,
    val monthShort: String,
    val title: String,
    val short: String,
    val kind: String,
    val color: Int,
)

/**
 * Decodes the `epochMillis|name|time|dateLabel[|secondaryName|secondaryTime]`
 * records that `HomeScreenWidgetService` joins with `;`. Malformed records are
 * skipped rather than failing the whole schedule.
 */
fun parsePrayerSchedule(raw: String): List<PrayerScheduleEntry> =
    raw.split(';')
        .mapNotNull { record ->
            if (record.isBlank()) return@mapNotNull null
            val parts = record.split('|', limit = 6)
            if (parts.size != 4 && parts.size != 6) return@mapNotNull null
            val millis = parts[0].trim().toLongOrNull() ?: return@mapNotNull null
            PrayerScheduleEntry(
                time = Instant.ofEpochMilli(millis),
                name = parts[1],
                displayTime = parts[2],
                dateLabel = parts[3],
                secondaryName = if (parts.size == 6) parts[4] else "",
                secondaryTime = if (parts.size == 6) parts[5] else "",
            )
        }
        .sortedBy { it.time }

private fun jsonArrayOrNull(raw: String): JSONArray? {
    if (raw.isBlank()) return null
    return try {
        JSONArray(raw)
    } catch (_: Exception) {
        null
    }
}

private fun JSONObject.text(key: String): String = optString(key, "").trim()

private fun JSONObject.millis(key: String): Long? {
    if (!has(key) || isNull(key)) return null
    val value = opt(key)
    return when (value) {
        is Number -> value.toLong()
        is String -> value.toDoubleOrNull()?.toLong()
        else -> null
    }
}

fun parseHijriDays(raw: String): List<HijriDay> {
    val array = jsonArrayOrNull(raw) ?: return emptyList()
    return (0 until array.length())
        .mapNotNull { index ->
            val entry = array.optJSONObject(index) ?: return@mapNotNull null
            val start = entry.millis("start") ?: return@mapNotNull null
            val day = entry.optInt("day", 0)
            if (day <= 0) return@mapNotNull null
            val event = entry.text("event")
            val eventShort = entry.text("eventShort")
            HijriDay(
                start = Instant.ofEpochMilli(start),
                day = day,
                month = entry.text("month"),
                monthShort = entry.text("monthShort"),
                year = entry.optInt("year", 0),
                event = event,
                eventShort = eventShort.ifEmpty { event },
                kind = entry.text("kind"),
                color = entry.optInt("color", -1),
            )
        }
        .sortedBy { it.start }
}

fun parseIslamicEvents(raw: String): List<IslamicEvent> {
    val array = jsonArrayOrNull(raw) ?: return emptyList()
    return (0 until array.length())
        .mapNotNull { index ->
            val entry = array.optJSONObject(index) ?: return@mapNotNull null
            val title = entry.text("title")
            val start = entry.millis("start") ?: return@mapNotNull null
            if (title.isEmpty()) return@mapNotNull null
            val short = entry.text("short")
            IslamicEvent(
                start = Instant.ofEpochMilli(start),
                day = entry.optInt("day", 0),
                monthShort = entry.text("monthShort"),
                title = title,
                short = short.ifEmpty { title },
                kind = entry.text("kind"),
                color = entry.optInt("color", -1),
            )
        }
        .sortedBy { it.start }
}

/**
 * How many prayer times a day of the phone's daily schedule holds, so the
 * watch lists as many as the phone's card does. Settings bounds the selection
 * to 3-5; anything else is a stale or malformed payload and gets the five
 * daily prayers.
 */
fun selectedPrayerCount(rawDailySchedule: String): Int {
    val fallback = 5
    val array = jsonArrayOrNull(rawDailySchedule) ?: return fallback
    val count = (0 until array.length())
        .map { array.optJSONObject(it)?.optJSONArray("items")?.length() ?: 0 }
        .firstOrNull { it > 0 }
        ?: return fallback
    return if (count in 3..5) count else fallback
}

/**
 * Everything the phone last sent, decoded. Pure data, so the screens, the
 * tile and the complications all read the same thing the same way, and the
 * rules below are unit-testable without a device.
 */
data class WatchSnapshot(
    val values: Map<String, String>,
    /** When the phone last sent anything; null before the first sync. */
    val updatedAt: Instant?,
) {
    private fun string(key: String): String = values[key].orEmpty().trim()

    val hasSyncedData: Boolean get() = updatedAt != null

    /**
     * The phone publishes placeholder rows ("Set location" / "Open app") with
     * an empty schedule when no location is chosen yet, and those must never
     * be shown as prayer times.
     */
    val hasPrayerTimes: Boolean get() = string(WatchDataKeys.PRAYER_SCHEDULE).isNotEmpty()

    val location: String get() = string(WatchDataKeys.PRAYER_LOCATION)

    val prayerSchedule: List<PrayerScheduleEntry> by lazy {
        parsePrayerSchedule(string(WatchDataKeys.PRAYER_SCHEDULE))
    }

    val calendarDays: List<HijriDay> by lazy { parseHijriDays(string(WatchDataKeys.CALENDAR_DAYS)) }

    private val calendarEvents: List<IslamicEvent> by lazy {
        parseIslamicEvents(string(WatchDataKeys.CALENDAR_EVENTS))
    }

    val selectedPrayerCount: Int by lazy {
        selectedPrayerCount(string(WatchDataKeys.DAILY_PRAYER_SCHEDULE))
    }

    fun nextPrayer(after: Instant): PrayerScheduleEntry? =
        prayerSchedule.firstOrNull { it.time.isAfter(after) }

    /**
     * The next [limit] times, soonest first. The schedule already holds only
     * the times chosen in the phone's Settings, spread over eight days, so a
     * prefix of it is the same rolling window the phone's home card shows.
     */
    fun upcomingPrayers(after: Instant, limit: Int = selectedPrayerCount): List<PrayerScheduleEntry> =
        if (limit <= 0) emptyList()
        else prayerSchedule.asSequence().filter { it.time.isAfter(after) }.take(limit).toList()

    /**
     * The hijri date at [at], or null when the phone has never sent one or the
     * run it sent has been used up. Each day starts at local midnight and lasts
     * at most 25 hours (DST), so the last one to have started is today only
     * within that window.
     */
    fun hijriDay(at: Instant): HijriDay? {
        val day = calendarDays.lastOrNull { !it.start.isAfter(at) } ?: return null
        return if (ChronoUnit.SECONDS.between(day.start, at) < 25 * 3600) day else null
    }

    /**
     * Events after [at]'s day, soonest first. Today's own is on [hijriDay], so
     * this is what comes next - unless there is no hijri date to carry it, in
     * which case today's is kept.
     */
    fun upcomingEvents(at: Instant, zone: ZoneId, limit: Int): List<IslamicEvent> {
        if (limit <= 0) return emptyList()
        val today = at.atZone(zone).toLocalDate()
        val cutoffDate = if (hijriDay(at) == null) today else today.plusDays(1)
        val cutoff = cutoffDate.atStartOfDay(zone).toInstant()
        return calendarEvents.asSequence().filter { !it.start.isBefore(cutoff) }.take(limit).toList()
    }

    /** Every instant the watch's view of the snapshot changes on its own. */
    fun transitionsAfter(at: Instant): List<Instant> =
        (prayerSchedule.map { it.time } + calendarDays.map { it.start })
            .filter { it.isAfter(at) }
            .distinct()
            .sorted()

    companion object {
        val EMPTY = WatchSnapshot(emptyMap(), null)
    }
}

/** Whole calendar days from [now]'s date to [start]'s, in [zone]. */
fun calendarDaysAway(start: Instant, now: Instant, zone: ZoneId): Long {
    val from: LocalDate = now.atZone(zone).toLocalDate()
    val to: LocalDate = start.atZone(zone).toLocalDate()
    return ChronoUnit.DAYS.between(from, to)
}
