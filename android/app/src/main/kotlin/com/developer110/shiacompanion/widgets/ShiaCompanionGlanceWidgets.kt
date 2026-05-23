package com.developer110.shiacompanion.widgets

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.Composable
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalContext
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.ColumnScope
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.color.ColorProvider

private const val WIDGET_PREFS = "shia_companion_widgets"

private const val KEY_FAVORITES_TITLE = "sc_favorites_title"
private const val KEY_FAVORITES_SUBTITLE = "sc_favorites_subtitle"
private const val KEY_FAVORITE_ITEM_1 = "sc_favorites_item_1"
private const val KEY_FAVORITE_ITEM_2 = "sc_favorites_item_2"
private const val KEY_FAVORITE_ITEM_3 = "sc_favorites_item_3"
private const val KEY_FAVORITE_URL_1 = "sc_favorites_url_1"
private const val KEY_FAVORITE_URL_2 = "sc_favorites_url_2"
private const val KEY_FAVORITE_URL_3 = "sc_favorites_url_3"

private const val KEY_RECITATION_TITLE = "sc_recitation_title"
private const val KEY_RECITATION_SUBTITLE = "sc_recitation_subtitle"
private const val KEY_RECITATION_ITEM_1 = "sc_recitation_item_1"
private const val KEY_RECITATION_ITEM_2 = "sc_recitation_item_2"
private const val KEY_RECITATION_ITEM_3 = "sc_recitation_item_3"
private const val KEY_RECITATION_URL_1 = "sc_recitation_url_1"
private const val KEY_RECITATION_URL_2 = "sc_recitation_url_2"
private const val KEY_RECITATION_URL_3 = "sc_recitation_url_3"

private const val KEY_PRAYER_TITLE = "sc_prayer_title"
private const val KEY_PRAYER_NAME = "sc_prayer_name"
private const val KEY_PRAYER_TIME = "sc_prayer_time"
private const val KEY_PRAYER_DATE = "sc_prayer_date"
private const val KEY_PRAYER_LOCATION = "sc_prayer_location"
private const val KEY_PRAYER_SCHEDULE = "sc_prayer_schedule"

private val backgroundColor = ColorProvider(
    day = androidx.compose.ui.graphics.Color(0xFF6D4C41),
    night = androidx.compose.ui.graphics.Color(0xFF241B17)
)
private val primaryTextColor = ColorProvider(
    day = androidx.compose.ui.graphics.Color(0xFFFFF8F1),
    night = androidx.compose.ui.graphics.Color(0xFFFFF3E7)
)
private val bodyTextColor = ColorProvider(
    day = androidx.compose.ui.graphics.Color(0xFFF7E4D3),
    night = androidx.compose.ui.graphics.Color(0xFFE9D5C4)
)
private val secondaryTextColor = ColorProvider(
    day = androidx.compose.ui.graphics.Color(0xFFE4C7B3),
    night = androidx.compose.ui.graphics.Color(0xFFBFA898)
)

class FavoritesWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            WidgetListContent(
                titleKey = KEY_FAVORITES_TITLE,
                titleFallback = "Favorites",
                subtitleKey = KEY_FAVORITES_SUBTITLE,
                subtitleFallback = "Open app to add favorites",
                itemKeys = listOf(KEY_FAVORITE_ITEM_1, KEY_FAVORITE_ITEM_2, KEY_FAVORITE_ITEM_3),
                itemUrlKeys = listOf(KEY_FAVORITE_URL_1, KEY_FAVORITE_URL_2, KEY_FAVORITE_URL_3),
                firstItemFallback = "No favorites yet"
            )
        }
    }
}

class FavoritesWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = FavoritesWidget()
}

class TodaysRecitationWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            WidgetListContent(
                titleKey = KEY_RECITATION_TITLE,
                titleFallback = "Today's Recitations",
                subtitleKey = KEY_RECITATION_SUBTITLE,
                subtitleFallback = "",
                itemKeys = listOf(KEY_RECITATION_ITEM_1, KEY_RECITATION_ITEM_2, KEY_RECITATION_ITEM_3),
                itemUrlKeys = listOf(KEY_RECITATION_URL_1, KEY_RECITATION_URL_2, KEY_RECITATION_URL_3),
                firstItemFallback = "Open app to refresh"
            )
        }
    }
}

class TodaysRecitationWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TodaysRecitationWidget()
}

class UpcomingPrayerWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            PrayerWidgetContent()
        }
    }
}

class UpcomingPrayerWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = UpcomingPrayerWidget()
}

@Composable
private fun WidgetListContent(
    titleKey: String,
    titleFallback: String,
    subtitleKey: String,
    subtitleFallback: String,
    itemKeys: List<String>,
    itemUrlKeys: List<String>,
    firstItemFallback: String
) {
    val context = LocalContext.current
    val data = context.widgetData()
    val items = itemKeys.mapIndexedNotNull { index, key ->
        val title = data.text(key, if (index == 0) firstItemFallback else "")
        if (title.isBlank()) {
            null
        } else {
            WidgetItem(
                title = title,
                url = data.text(itemUrlKeys[index], "")
            )
        }
    }

    WidgetSurface(clickable = false) {
        Text(
            text = data.text(titleKey, titleFallback),
            style = TextStyle(
                color = primaryTextColor,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
        val subtitle = data.text(subtitleKey, subtitleFallback)
        if (subtitle.isNotBlank()) {
            Text(
                text = subtitle,
                style = TextStyle(color = secondaryTextColor, fontSize = 12.sp),
                maxLines = 1
            )
        }
        Spacer(GlanceModifier.height(8.dp))
        items.take(3).forEach { item ->
            val modifier = item.url
                .takeIf { it.isNotBlank() }
                ?.let { GlanceModifier.clickable(actionStartActivity(context.openUrlIntent(it))) }
                ?: GlanceModifier
            Text(
                text = item.title,
                modifier = modifier,
                style = TextStyle(color = bodyTextColor, fontSize = 12.sp),
                maxLines = 1
            )
        }
    }
}

@Composable
private fun PrayerWidgetContent() {
    val context = LocalContext.current
    val data = context.widgetData()
    val prayer = data.nextPrayer()

    WidgetSurface(clickable = true) {
        Text(
            text = data.text(KEY_PRAYER_TITLE, "Upcoming Prayer"),
            style = TextStyle(
                color = secondaryTextColor,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
        Text(
            text = prayer.name,
            style = TextStyle(
                color = primaryTextColor,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
        Text(
            text = prayer.time,
            style = TextStyle(
                color = bodyTextColor,
                fontSize = 22.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
        Text(
            text = prayer.dateLabel,
            style = TextStyle(color = secondaryTextColor, fontSize = 12.sp),
            maxLines = 1
        )
        Spacer(GlanceModifier.defaultWeight())
        Text(
            text = prayer.location,
            style = TextStyle(color = secondaryTextColor, fontSize = 11.sp),
            maxLines = 1
        )
    }
}

@Composable
private fun WidgetSurface(
    clickable: Boolean,
    content: @Composable ColumnScope.() -> Unit
) {
    val context = LocalContext.current
    val modifier = GlanceModifier
        .fillMaxSize()
        .background(backgroundColor)
        .cornerRadius(14.dp)
        .let {
            if (clickable) {
                it.clickable(actionStartActivity(context.openAppIntent()))
            } else {
                it
            }
        }
        .padding(14.dp)

    Column(
        modifier = modifier,
        verticalAlignment = Alignment.Top,
        horizontalAlignment = Alignment.Start,
        content = content
    )
}

private fun Context.widgetData() = getSharedPreferences(WIDGET_PREFS, Context.MODE_PRIVATE)

private data class WidgetItem(
    val title: String,
    val url: String
)

private fun Context.openUrlIntent(url: String): Intent {
    return Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
        setPackage(packageName)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
}

private fun Context.openAppIntent(): Intent {
    return packageManager.getLaunchIntentForPackage(packageName)?.apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    } ?: Intent(Intent.ACTION_MAIN).apply {
        setPackage(packageName)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }
}

private fun android.content.SharedPreferences.text(key: String, fallback: String): String {
    return getString(key, fallback)?.takeIf { it.isNotBlank() } ?: fallback
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

private fun android.content.SharedPreferences.nextPrayer(): PrayerDisplay {
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
