package com.developer110.shiacompanion.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import com.developer110.shiacompanion.R
import es.antonborri.home_widget.HomeWidgetProvider

private const val KEY_FAVORITES_TITLE = "sc_favorites_title"
private const val KEY_FAVORITES_SUBTITLE = "sc_favorites_subtitle"
private const val KEY_FAVORITE_ITEM_1 = "sc_favorites_item_1"
private const val KEY_FAVORITE_ITEM_2 = "sc_favorites_item_2"
private const val KEY_FAVORITE_ITEM_3 = "sc_favorites_item_3"

private const val KEY_RECITATION_TITLE = "sc_recitation_title"
private const val KEY_RECITATION_SUBTITLE = "sc_recitation_subtitle"
private const val KEY_RECITATION_ITEM_1 = "sc_recitation_item_1"
private const val KEY_RECITATION_ITEM_2 = "sc_recitation_item_2"
private const val KEY_RECITATION_ITEM_3 = "sc_recitation_item_3"

private const val KEY_PRAYER_TITLE = "sc_prayer_title"
private const val KEY_PRAYER_NAME = "sc_prayer_name"
private const val KEY_PRAYER_TIME = "sc_prayer_time"
private const val KEY_PRAYER_DATE = "sc_prayer_date"
private const val KEY_PRAYER_LOCATION = "sc_prayer_location"
private const val KEY_PRAYER_SCHEDULE = "sc_prayer_schedule"

class FavoritesWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_favorites).apply {
                setTextViewText(R.id.widget_title, widgetData.text(KEY_FAVORITES_TITLE, "Favorites"))
                setTextViewText(
                    R.id.widget_subtitle,
                    widgetData.text(KEY_FAVORITES_SUBTITLE, "Open app to add favorites")
                )
                setTextOrHide(R.id.widget_item_1, widgetData.text(KEY_FAVORITE_ITEM_1, "No favorites yet"))
                setTextOrHide(R.id.widget_item_2, widgetData.text(KEY_FAVORITE_ITEM_2, ""))
                setTextOrHide(R.id.widget_item_3, widgetData.text(KEY_FAVORITE_ITEM_3, ""))
                setOpenAppTap(context, widgetId)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class TodaysRecitationWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_recitation).apply {
                setTextViewText(
                    R.id.widget_title,
                    widgetData.text(KEY_RECITATION_TITLE, "Today's Recitations")
                )
                setTextViewText(R.id.widget_subtitle, widgetData.text(KEY_RECITATION_SUBTITLE, ""))
                setTextOrHide(
                    R.id.widget_item_1,
                    widgetData.text(KEY_RECITATION_ITEM_1, "Open app to refresh")
                )
                setTextOrHide(R.id.widget_item_2, widgetData.text(KEY_RECITATION_ITEM_2, ""))
                setTextOrHide(R.id.widget_item_3, widgetData.text(KEY_RECITATION_ITEM_3, ""))
                setOpenAppTap(context, widgetId)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class UpcomingPrayerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val prayer = widgetData.nextPrayer()
            val views = RemoteViews(context.packageName, R.layout.widget_prayer_time).apply {
                setTextViewText(R.id.widget_title, widgetData.text(KEY_PRAYER_TITLE, "Upcoming Prayer"))
                setTextViewText(R.id.widget_prayer_name, prayer.name)
                setTextViewText(R.id.widget_prayer_time, prayer.time)
                setTextViewText(R.id.widget_prayer_date, prayer.dateLabel)
                setTextViewText(R.id.widget_location, prayer.location)
                setOpenAppTap(context, widgetId)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

private data class PrayerDisplay(
    val name: String,
    val time: String,
    val dateLabel: String,
    val location: String
)

private data class PrayerEntry(
    val epochMillis: Long,
    val name: String,
    val time: String,
    val dateLabel: String
)

private fun SharedPreferences.text(key: String, fallback: String): String {
    return getString(key, fallback)?.takeIf { it.isNotBlank() } ?: fallback
}

private fun SharedPreferences.nextPrayer(): PrayerDisplay {
    val location = text(KEY_PRAYER_LOCATION, "Location needed")
    val now = System.currentTimeMillis()
    val next = getString(KEY_PRAYER_SCHEDULE, "")
        ?.split(';')
        ?.mapNotNull { rawEntry ->
            val parts = rawEntry.split('|', limit = 4)
            if (parts.size != 4) return@mapNotNull null
            val epochMillis = parts[0].toLongOrNull() ?: return@mapNotNull null
            PrayerEntry(
                epochMillis = epochMillis,
                name = parts[1],
                time = parts[2],
                dateLabel = parts[3]
            )
        }
        ?.filter { it.epochMillis > now }
        ?.minByOrNull { it.epochMillis }

    if (next != null) {
        return PrayerDisplay(
            name = next.name,
            time = next.time,
            dateLabel = next.dateLabel,
            location = location
        )
    }

    return PrayerDisplay(
        name = text(KEY_PRAYER_NAME, "Prayer Times"),
        time = text(KEY_PRAYER_TIME, "Set location"),
        dateLabel = text(KEY_PRAYER_DATE, "Open app"),
        location = location
    )
}

private fun RemoteViews.setTextOrHide(viewId: Int, value: String) {
    if (value.isBlank()) {
        setViewVisibility(viewId, View.GONE)
    } else {
        setTextViewText(viewId, value)
        setViewVisibility(viewId, View.VISIBLE)
    }
}

private fun RemoteViews.setOpenAppTap(context: Context, widgetId: Int) {
    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        ?: return
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or (
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )
    val pendingIntent = PendingIntent.getActivity(context, widgetId, launchIntent, flags)
    setOnClickPendingIntent(R.id.widget_root, pendingIntent)
}
