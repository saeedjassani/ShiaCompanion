package com.developer110.shiacompanion.wear

import com.developer110.shiacompanion.wear.data.WatchDataKeys
import com.developer110.shiacompanion.wear.data.WatchSnapshot
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import org.json.JSONArray
import org.json.JSONObject

/**
 * A snapshot shaped exactly like the one the phone's HomeScreenWidgetService
 * publishes, for a reader in Karbala on 24 October 2026 at 14:00.
 */
object SampleSnapshot {
    val zone: ZoneId = ZoneId.of("Asia/Baghdad")
    val today: LocalDate = LocalDate.of(2026, 10, 24)
    val now: Instant = at(today, "14:00")

    data class Names(
        val fajr: String = "Fajr",
        val zuhr: String = "Zuhr",
        val asr: String = "Asr",
        val maghrib: String = "Maghrib",
        val isha: String = "Isha",
        val today: String = "Today",
        val tomorrow: String = "Tomorrow",
    )

    val urdu = Names("فجر", "ظہر", "عصر", "مغرب", "عشاء", "آج", "کل")

    fun at(date: LocalDate, time: String): Instant =
        date.atTime(LocalTime.parse(time)).atZone(zone).toInstant()

    private fun times(names: Names) = listOf(
        names.fajr to "04:52" to "4:52 AM",
        names.zuhr to "11:44" to "11:44 AM",
        names.asr to "14:58" to "2:58 PM",
        names.maghrib to "17:22" to "5:22 PM",
        names.isha to "18:37" to "6:37 PM",
    )

    fun values(names: Names = Names(), location: String = "Karbala"): Map<String, String> {
        val schedule = (0 until 8).flatMap { offset ->
            val date = today.plusDays(offset.toLong())
            val label = when (offset) {
                0 -> names.today
                1 -> names.tomorrow
                else -> "${date.monthValue}/${date.dayOfMonth}"
            }
            times(names).map { (nameAndTime, display) ->
                val (name, time) = nameAndTime
                "${at(date, time).toEpochMilli()}|$name|$display|$label"
            }
        }.joinToString(";")

        val daily = JSONArray().apply {
            put(JSONObject().put("start", at(today, "00:00").toEpochMilli()).put("items",
                JSONArray().apply { times(names).forEach { put(JSONObject().put("title", it.first.first)) } }))
        }

        val days = JSONArray().apply {
            (0 until 30).forEach { offset ->
                val day = 13 + offset
                val (month, short, dayOfMonth) = if (day <= 30) Triple("Jumada al-Awwal", "Jum I", day)
                else Triple("Jumada al-Akhirah", "Jum II", day - 30)
                put(
                    JSONObject()
                        .put("start", at(today.plusDays(offset.toLong()), "00:00").toEpochMilli())
                        .put("day", dayOfMonth)
                        .put("month", month)
                        .put("monthShort", short)
                        .put("year", 1448)
                        .put("event", if (offset == 0) "Hazrat Fatima Zahra (s.a.)" else "")
                        .put("eventShort", if (offset == 0) "H. Fatima Zahra (s.a.)" else "")
                        .put("kind", if (offset == 0) "Martyrdom" else "")
                        .put("color", if (offset == 0) 0 else -1)
                )
            }
        }

        val events = JSONArray().apply {
            listOf(
                Triple(20, "Hazrat Fatima Zahra (s.a.)", Triple(3, "Jum II", "Martyrdom") to 0),
                Triple(37, "Hazrat Fatima Zahra (s.a.)", Triple(20, "Jum II", "Birth") to 1),
                Triple(66, "Imam Ali (a.s.)", Triple(13, "Raj", "Birth") to 1),
            ).forEach { (offset, title, meta) ->
                val (details, color) = meta
                put(
                    JSONObject()
                        .put("start", at(today.plusDays(offset.toLong()), "00:00").toEpochMilli())
                        .put("day", details.first)
                        .put("monthShort", details.second)
                        .put("title", title)
                        .put("short", title.replace("Hazrat ", "H. ").replace("Imam ", "I. "))
                        .put("kind", details.third)
                        .put("color", color)
                )
            }
        }

        return mapOf(
            WatchDataKeys.PRAYER_LOCATION to location,
            WatchDataKeys.PRAYER_SCHEDULE to schedule,
            WatchDataKeys.DAILY_PRAYER_SCHEDULE to daily.toString(),
            WatchDataKeys.CALENDAR_DAYS to days.toString(),
            WatchDataKeys.CALENDAR_EVENTS to events.toString(),
        )
    }

    fun snapshot(names: Names = Names()): WatchSnapshot =
        WatchSnapshot(values(names), now.minusSeconds(5 * 60))

    /** What the phone sends before a location is chosen: placeholders and no schedule. */
    val noLocation = WatchSnapshot(
        mapOf(WatchDataKeys.PRAYER_LOCATION to "Location needed", WatchDataKeys.PRAYER_SCHEDULE to ""),
        now.minusSeconds(60),
    )
}
