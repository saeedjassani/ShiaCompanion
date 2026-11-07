package com.developer110.shiacompanion.widgets

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import java.util.Calendar
import org.json.JSONArray
import org.json.JSONObject

/**
 * What the Flutter app publishes to the widgets (see
 * lib/services/home_screen_widget_service.dart), in the same keys and formats.
 */
internal object WidgetTestData {
    const val PREFS = "shia_companion_widgets"

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().commit()
    }

    /** A user with a saved location, favorites and today's recitations. */
    fun publish(context: Context, now: Long = System.currentTimeMillis()) {
        val hour = 60L * 60L * 1000L
        val prayers = listOf(
            "Zuhr" to "12:30 pm",
            "Asr" to "3:45 pm",
            "Maghrib" to "6:10 pm",
            "Isha" to "7:30 pm",
            "Fajr" to "5:05 am",
            "Sunrise" to "6:30 am"
        )
        val schedule = prayers.mapIndexed { index, (name, time) ->
            "${now + (index + 1) * 2 * hour}|$name|$time|Today"
        }.joinToString(";")

        val startOfToday = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val day = 24L * hour
        val days = JSONArray().apply {
            for (offset in 0 until 3) {
                put(JSONObject().apply {
                    put("start", startOfToday + offset * day)
                    put("day", 11 + offset)
                    put("month", "Jumada al-Awwal")
                    put("monthShort", "Jum I")
                    put("year", 1448)
                    if (offset == 0) {
                        put("event", "Hazrat Fatima Zahra (s.a.)")
                        put("eventShort", "H. Fatima Zahra (s.a.)")
                        put("kind", "Birth")
                        put("color", 1)
                    }
                })
            }
        }
        val events = JSONArray().apply {
            for (offset in 1..6) {
                put(JSONObject().apply {
                    put("start", startOfToday + offset * 3 * day)
                    put("day", 11 + offset * 3)
                    put("monthShort", "Jum I")
                    put("title", "Event $offset")
                    put("short", "Ev $offset")
                    put("kind", if (offset % 2 == 0) "Martyrdom" else "Birth")
                    put("color", offset % 2)
                })
            }
        }
        val recitationSchedule = JSONArray().apply {
            put(JSONObject().apply {
                put("start", startOfToday)
                put("items", JSONArray().apply {
                    put(JSONObject().put("title", "Dua Kumayl").put("url", "/zikr/dua-kumayl"))
                    put(JSONObject().put("title", "Ziyarat Ashura").put("url", "/zikr/ziyarat-ashura"))
                })
            })
        }

        val values = buildMap {
            put("sc_favorites_title", "Favorites")
            put("sc_favorites_item_1", "Dua Ahad")
            put("sc_favorites_url_1", "/zikr/dua-ahad")
            put("sc_favorites_item_2", "36: Ya-Sin يس")
            put("sc_favorites_url_2", "/zikr/yasin")
            put("sc_recitation_title", "Today's Recitations")
            put("sc_recitation_item_1", "Dua Kumayl")
            put("sc_recitation_url_1", "/zikr/dua-kumayl")
            put("sc_recitation_schedule", recitationSchedule.toString())
            put("sc_prayer_title", "Up Next")
            put("sc_prayer_name", "Zuhr")
            put("sc_prayer_time", "12:30 pm")
            put("sc_prayer_location", "Karachi")
            put("sc_prayer_schedule", schedule)
            put("sc_daily_prayer_title", "Prayer Times")
            prayers.take(5).forEachIndexed { index, (name, time) ->
                put("sc_daily_prayer_name_${index + 1}", name)
                put("sc_daily_prayer_time_${index + 1}", time)
            }
            put("sc_calendar_days", days.toString())
            put("sc_calendar_events", events.toString())
            put("sc_calendar_url", "/calendar")
        }
        val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        values.forEach { (key, value) -> editor.putString(key, value) }
        editor.commit()
    }

    /** A non-brown Color setting: the palette the app publishes as sc_color_*. */
    fun publishPalette(context: Context) {
        val tokens = listOf(
            "surface", "border", "primary_text", "body_text", "secondary_text", "divider",
            "accent", "event_joy", "event_mourning"
        )
        val editor = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        tokens.forEach {
            editor.putString("sc_color_${it}_day", "#FF204060")
            editor.putString("sc_color_${it}_night", "#FFE0E0F0")
        }
        editor.commit()
    }
}

/** Every visible TextView's text under [view], depth first. */
internal fun visibleTexts(view: View): List<String> {
    if (view.visibility != View.VISIBLE) return emptyList()
    val own = if (view is TextView && view.text.isNotBlank()) listOf(view.text.toString()) else emptyList()
    if (view !is ViewGroup) return own
    return own + (0 until view.childCount).flatMap { visibleTexts(view.getChildAt(it)) }
}

/** Whether [view] holds Glance's loading spinner (its initialLayout). */
internal fun isLoadingLayout(view: View): Boolean {
    if (view is android.widget.ProgressBar && view.visibility == View.VISIBLE) return true
    if (view !is ViewGroup) return false
    return (0 until view.childCount).any { isLoadingLayout(view.getChildAt(it)) }
}
