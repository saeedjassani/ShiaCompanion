package com.developer110.shiacompanion.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
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
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.lazy.items
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.ColumnScope
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.color.ColorProvider
import com.developer110.shia_companion.MainActivity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

private const val WIDGET_PREFS = "shia_companion_widgets"
private const val WIDGET_URL_EXTRA = "com.developer110.shiacompanion.WIDGET_URL"
private const val PRAYER_TIMES_URL = "https://shia-companion.web.app/calendar-prayer-times"
private const val ACTION_REFRESH_PRAYER_WIDGET =
    "com.developer110.shiacompanion.widgets.REFRESH_PRAYER_WIDGET"

private const val KEY_FAVORITES_TITLE = "sc_favorites_title"
private const val KEY_FAVORITES_SUBTITLE = "sc_favorites_subtitle"
private val favoriteItemKeys = (1..8).map { "sc_favorites_item_$it" }
private val favoriteUrlKeys = (1..8).map { "sc_favorites_url_$it" }

private const val KEY_RECITATION_TITLE = "sc_recitation_title"
private const val KEY_RECITATION_SUBTITLE = "sc_recitation_subtitle"
private val recitationItemKeys = (1..8).map { "sc_recitation_item_$it" }
private val recitationUrlKeys = (1..8).map { "sc_recitation_url_$it" }

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
                itemKeys = favoriteItemKeys,
                itemUrlKeys = favoriteUrlKeys,
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
                itemKeys = recitationItemKeys,
                itemUrlKeys = recitationUrlKeys,
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

class PrayerWidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_REFRESH_PRAYER_WIDGET) return

        CoroutineScope(Dispatchers.Main).launch {
            UpcomingPrayerWidget().updateAll(context.applicationContext)
            scheduleNextPrayerWidgetRefresh(context.applicationContext)
        }
    }
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
        if (items.size == 1 && items.first().url.isBlank()) {
            Text(
                text = items.first().title,
                modifier = GlanceModifier.fillMaxWidth(),
                style = TextStyle(
                    color = bodyTextColor,
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center
                ),
                maxLines = 2
            )
            Spacer(GlanceModifier.defaultWeight())
            return@WidgetSurface
        }
        LazyColumn(modifier = GlanceModifier.defaultWeight()) {
            items(items) { item ->
                val modifier = item.url
                    .takeIf { it.isNotBlank() }
                    ?.let { GlanceModifier.clickable(actionStartActivity(context.openUrlIntent(it))) }
                    ?: GlanceModifier
                Text(
                    text = "${item.title}  ›",
                    modifier = modifier.fillMaxWidth().height(26.dp),
                    style = TextStyle(color = bodyTextColor, fontSize = 12.sp),
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
private fun PrayerWidgetContent() {
    val context = LocalContext.current
    val data = context.widgetData()
    val prayer = data.nextPrayer()

    WidgetSurface(clickable = true, clickUrl = PRAYER_TIMES_URL) {
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
    clickUrl: String? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    val context = LocalContext.current
    val modifier = GlanceModifier
        .fillMaxSize()
        .background(backgroundColor)
        .cornerRadius(14.dp)
        .let {
            if (clickable) {
                it.clickable(actionStartActivity(context.openWidgetIntent(clickUrl)))
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

fun scheduleNextPrayerWidgetRefresh(context: Context) {
    val nextPrayer = context.widgetData().nextPrayerEpochMillis() ?: return
    val triggerAt = nextPrayer + 60_000L
    if (triggerAt <= System.currentTimeMillis()) return

    val intent = Intent(context, PrayerWidgetRefreshReceiver::class.java).apply {
        action = ACTION_REFRESH_PRAYER_WIDGET
    }
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or (
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )
    val pendingIntent = PendingIntent.getBroadcast(context, 0, intent, flags)
    val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent
            )
        } else {
            alarmManager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    } catch (_: SecurityException) {
        alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
    }
}

private data class WidgetItem(
    val title: String,
    val url: String
)

private fun Context.openUrlIntent(url: String): Intent {
    return openWidgetIntent(url)
}

private fun Context.openWidgetIntent(url: String?): Intent {
    return Intent(this, MainActivity::class.java).apply {
        action = Intent.ACTION_MAIN
        addCategory(Intent.CATEGORY_LAUNCHER)
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        url?.takeIf { it.isNotBlank() }?.let {
            putExtra(WIDGET_URL_EXTRA, it)
        }
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

private fun android.content.SharedPreferences.nextPrayerEpochMillis(): Long? {
    val now = System.currentTimeMillis()
    return getString(KEY_PRAYER_SCHEDULE, "")
        ?.split(';')
        ?.mapNotNull { rawEntry ->
            val parts = rawEntry.split('|', limit = 4)
            if (parts.size != 4) return@mapNotNull null
            parts[0].toLongOrNull()
        }
        ?.filter { it > now }
        ?.minOrNull()
}
