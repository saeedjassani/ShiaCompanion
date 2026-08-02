package com.developer110.shiacompanion.wear

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import java.util.Calendar

/** Data layer paths. Must stay in sync with `WearSnapshot` in the phone app. */
object WearSyncPaths {
    const val PRAYER_SNAPSHOT = "/shia_companion/prayer_snapshot"
    const val REQUEST_SNAPSHOT = "/shia_companion/request_snapshot"
}

/**
 * Keys shared with the phone app (`WearSnapshotPublisher`) and, upstream of it, with the
 * Flutter side's `HomeScreenWidgetService`.
 *
 * NOTE: a Wear OS app has its own storage on the watch — nothing the phone writes to its
 * own preferences is visible here. Everything below is written by [PhoneSyncManager] from
 * data items the phone publishes, and read back by the watch app, its tile and its
 * complication (which do share this container, since all three live on the watch).
 */
object WearDataKeys {
    const val PRAYER_LOCATION = "sc_prayer_location"
    const val PRAYER_SCHEDULE = "sc_prayer_schedule"
    const val PRAYER_NAME = "sc_prayer_name"
    const val PRAYER_TIME = "sc_prayer_time"
    const val PRAYER_DATE = "sc_prayer_date"
    const val PRAYER_SECONDARY_NAME = "sc_prayer_secondary_name"
    const val PRAYER_SECONDARY_TIME = "sc_prayer_secondary_time"

    val DAILY_PRAYER_NAMES = (1..5).map { "sc_daily_prayer_name_$it" }
    val DAILY_PRAYER_TIMES = (1..5).map { "sc_daily_prayer_time_$it" }
    const val DAILY_PRAYER_SCHEDULE = "sc_daily_prayer_schedule"

    /** Epoch millis of the last payload the phone sent. Absent until the first sync. */
    const val UPDATED_AT = "sc_watch_updated_at"

    val STRING_KEYS: List<String> = buildList {
        add(PRAYER_LOCATION)
        add(PRAYER_SCHEDULE)
        add(PRAYER_NAME)
        add(PRAYER_TIME)
        add(PRAYER_DATE)
        add(PRAYER_SECONDARY_NAME)
        add(PRAYER_SECONDARY_TIME)
        add(DAILY_PRAYER_SCHEDULE)
        addAll(DAILY_PRAYER_NAMES)
        addAll(DAILY_PRAYER_TIMES)
    }
}

/** One of the five daily prayers, as rendered in a list. */
data class PrayerEntry(val name: String, val time: String)

/** One upcoming prayer/period on the eight-day timeline the phone publishes. */
data class PrayerScheduleEntry(
    val epochMillis: Long,
    val name: String,
    val time: String,
    val dateLabel: String,
    val secondaryName: String,
    val secondaryTime: String,
)

/**
 * Local storage for the last snapshot received from the phone.
 *
 * Backed by preferences rather than memory so the tile and the complication — which run
 * in their own service processes, without the app — read the same data the app shows.
 */
class PrayerDataStore private constructor(private val prefs: SharedPreferences) {

    companion object {
        private const val PREFS_NAME = "shia_companion_wear"

        @Volatile
        private var instance: PrayerDataStore? = null

        fun get(context: Context): PrayerDataStore {
            return instance ?: synchronized(this) {
                instance ?: PrayerDataStore(
                    context.applicationContext
                        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                ).also { instance = it }
            }
        }

        /** Builds a store over arbitrary preferences. Visible for tests. */
        internal fun forPreferences(prefs: SharedPreferences) = PrayerDataStore(prefs)
    }

    /** `true` once the phone has sent at least one snapshot. */
    val hasSyncedData: Boolean
        get() = prefs.contains(WearDataKeys.UPDATED_AT)

    /**
     * `true` when the synced snapshot actually contains prayer times. The phone publishes
     * placeholder rows ("Set location" / "Open app") when no location has been chosen yet,
     * and those must not be rendered as prayer times.
     */
    val hasPrayerTimes: Boolean
        get() = string(WearDataKeys.PRAYER_SCHEDULE).isNotEmpty()

    val lastSyncedAtMillis: Long?
        get() = prefs.getLong(WearDataKeys.UPDATED_AT, 0L).takeIf { it > 0L }

    val location: String
        get() = string(WearDataKeys.PRAYER_LOCATION)

    fun string(key: String): String = prefs.getString(key, "").orEmpty().trim()

    /**
     * Merges a payload received from the phone. Only known keys are written, so a
     * malformed data item cannot pollute the container.
     */
    fun apply(payload: Map<String, Any?>) {
        val editor = prefs.edit()
        var wroteSomething = false

        for (key in WearDataKeys.STRING_KEYS) {
            val value = payload[key] ?: continue
            editor.putString(key, value.toString())
            wroteSomething = true
        }

        val updatedAt = payload[WearDataKeys.UPDATED_AT]
        when {
            updatedAt is Number -> {
                editor.putLong(WearDataKeys.UPDATED_AT, updatedAt.toLong())
                wroteSomething = true
            }
            // A payload without a usable timestamp still counts as a successful sync.
            wroteSomething -> editor.putLong(
                WearDataKeys.UPDATED_AT,
                System.currentTimeMillis()
            )
        }

        if (wroteSomething) editor.apply()
    }

    /** The upcoming prayer/period timeline (eight days), sorted ascending. */
    val prayerSchedule: List<PrayerScheduleEntry>
        get() = parsePrayerSchedule(string(WearDataKeys.PRAYER_SCHEDULE))

    fun nextPrayer(afterMillis: Long = System.currentTimeMillis()): PrayerScheduleEntry? =
        prayerSchedule.firstOrNull { it.epochMillis > afterMillis }

    /** Every prayer still ahead of [afterMillis], for the tile's timeline. */
    fun upcomingPrayers(afterMillis: Long = System.currentTimeMillis()): List<PrayerScheduleEntry> =
        prayerSchedule.filter { it.epochMillis > afterMillis }

    /**
     * The five daily prayer times for the given day.
     *
     * Prefers the multi-day JSON schedule so the watch rolls over to the next day on its
     * own; falls back to the flat `sc_daily_prayer_*` keys (which only ever hold the day
     * the phone last published).
     */
    fun dailyPrayers(atMillis: Long = System.currentTimeMillis()): List<PrayerEntry> {
        val fromSchedule = dailyPrayersFromSchedule(atMillis)
        if (!fromSchedule.isNullOrEmpty()) return fromSchedule

        return WearDataKeys.DAILY_PRAYER_NAMES.mapIndexedNotNull { index, key ->
            val name = string(key)
            val time = string(WearDataKeys.DAILY_PRAYER_TIMES[index])
            if (name.isEmpty() || time.isEmpty()) null else PrayerEntry(name, time)
        }
    }

    private fun dailyPrayersFromSchedule(atMillis: Long): List<PrayerEntry>? {
        val raw = string(WearDataKeys.DAILY_PRAYER_SCHEDULE)
        if (raw.isEmpty()) return null

        return try {
            val days = JSONArray(raw)
            val match = (0 until days.length())
                .map { days.getJSONObject(it) }
                .firstOrNull { isSameDay(it.optLong("start"), atMillis) }
                ?: return null

            val items = match.optJSONArray("items") ?: return null
            (0 until items.length()).mapNotNull { index ->
                val item = items.getJSONObject(index)
                val name = item.optString("title").trim()
                val time = item.optString("time").trim()
                if (name.isEmpty() || time.isEmpty()) null else PrayerEntry(name, time)
            }
        } catch (_: Exception) {
            null
        }
    }
}

internal fun isSameDay(firstMillis: Long, secondMillis: Long): Boolean {
    if (firstMillis <= 0L) return false

    val first = Calendar.getInstance().apply { timeInMillis = firstMillis }
    val second = Calendar.getInstance().apply { timeInMillis = secondMillis }
    return first.get(Calendar.YEAR) == second.get(Calendar.YEAR) &&
        first.get(Calendar.DAY_OF_YEAR) == second.get(Calendar.DAY_OF_YEAR)
}

/**
 * Decodes the `epochMillis|name|time|dateLabel[|secondaryName|secondaryTime]` records that
 * `HomeScreenWidgetService` joins with `;`.
 */
fun parsePrayerSchedule(rawSchedule: String): List<PrayerScheduleEntry> {
    if (rawSchedule.isBlank()) return emptyList()

    return rawSchedule.split(';')
        .mapNotNull { rawEntry ->
            val parts = rawEntry.split('|', limit = 6)
            if (parts.size != 4 && parts.size != 6) return@mapNotNull null
            val epochMillis = parts[0].toLongOrNull() ?: return@mapNotNull null

            PrayerScheduleEntry(
                epochMillis = epochMillis,
                name = parts[1],
                time = parts[2],
                dateLabel = parts[3],
                secondaryName = parts.getOrNull(4).orEmpty(),
                secondaryTime = parts.getOrNull(5).orEmpty(),
            )
        }
        .sortedBy { it.epochMillis }
}

/** Time without the meridiem, for the tight circular complication. */
fun compactTime(time: String): String = time.trim().substringBefore(' ')

/** How long until [targetMillis], as "2h 5m" / "40m" / "3d". Empty once it has passed. */
fun remainingTime(targetMillis: Long, nowMillis: Long = System.currentTimeMillis()): String {
    val remaining = targetMillis - nowMillis
    if (remaining <= 0L) return ""

    val totalMinutes = ((remaining + 59_999L) / 60_000L).coerceAtLeast(1L)
    val days = totalMinutes / (24L * 60L)
    val hours = (totalMinutes % (24L * 60L)) / 60L
    val minutes = totalMinutes % 60L

    return when {
        days > 0L && hours > 0L -> "${days}d ${hours}h"
        days > 0L -> "${days}d"
        hours > 0L && minutes > 0L -> "${hours}h ${minutes}m"
        hours > 0L -> "${hours}h"
        else -> "${minutes}m"
    }
}

/** Icon for a prayer/period name. Shared by the app, the tile and the complication. */
fun prayerIconRes(prayerName: String): Int {
    val name = prayerName.lowercase()
    return when {
        name.contains("fajr") -> R.drawable.ic_prayer_fajr
        name.contains("sunrise") -> R.drawable.ic_prayer_fajr
        name.contains("zuhr") || name.contains("dhuhr") || name.contains("dhohr") ->
            R.drawable.ic_prayer_zuhr
        name.contains("asr") -> R.drawable.ic_prayer_asr
        name.contains("maghrib") || name.contains("sunset") -> R.drawable.ic_prayer_maghrib
        name.contains("isha") || name.contains("midnight") -> R.drawable.ic_prayer_isha
        else -> R.drawable.ic_prayer_zuhr
    }
}
