package com.developer110.shiacompanion.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
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
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ColumnScope
import androidx.glance.layout.Row
import androidx.glance.layout.RowScope
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.color.ColorProvider
import com.developer110.shiacompanion.R
import com.developer110.shia_companion.MainActivity
import java.util.Calendar
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray

private const val WIDGET_PREFS = "shia_companion_widgets"
private const val WIDGET_URL_EXTRA = "com.developer110.shiacompanion.WIDGET_URL"
private const val ACTION_REFRESH_PRAYER_WIDGET =
    "com.developer110.shiacompanion.widgets.REFRESH_PRAYER_WIDGET"
private const val ACTION_REFRESH_RECITATION_WIDGET =
    "com.developer110.shiacompanion.widgets.REFRESH_RECITATION_WIDGET"

private const val KEY_FAVORITES_TITLE = "sc_favorites_title"
private val favoriteItemKeys = (1..12).map { "sc_favorites_item_$it" }
private val favoriteUrlKeys = (1..12).map { "sc_favorites_url_$it" }

private const val KEY_RECITATION_TITLE = "sc_recitation_title"
private val recitationItemKeys = (1..12).map { "sc_recitation_item_$it" }
private val recitationUrlKeys = (1..12).map { "sc_recitation_url_$it" }
private const val KEY_RECITATION_SCHEDULE = "sc_recitation_schedule"

private const val KEY_PRAYER_TITLE = "sc_prayer_title"
private const val KEY_PRAYER_NAME = "sc_prayer_name"
private const val KEY_PRAYER_TIME = "sc_prayer_time"
private const val KEY_PRAYER_LOCATION = "sc_prayer_location"
private const val KEY_PRAYER_SCHEDULE = "sc_prayer_schedule"
private const val KEY_PRAYER_SECONDARY_NAME = "sc_prayer_secondary_name"
private const val KEY_PRAYER_SECONDARY_TIME = "sc_prayer_secondary_time"

private const val KEY_DAILY_PRAYER_TITLE = "sc_daily_prayer_title"
private val dailyPrayerNameKeys = (1..5).map { "sc_daily_prayer_name_$it" }
private val dailyPrayerTimeKeys = (1..5).map { "sc_daily_prayer_time_$it" }
private const val KEY_DAILY_PRAYER_SCHEDULE = "sc_daily_prayer_schedule"

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
private val accentColor = ColorProvider(
    day = androidx.compose.ui.graphics.Color(0xFFFFC857),
    night = androidx.compose.ui.graphics.Color(0xFFFFD879)
)
private val iconBackgroundColor = ColorProvider(
    day = androidx.compose.ui.graphics.Color(0x33FFC857),
    night = androidx.compose.ui.graphics.Color(0x29FFD879)
)

class FavoritesWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            WidgetListContent(
                titleKey = KEY_FAVORITES_TITLE,
                titleFallback = "Favorites",
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
                itemKeys = recitationItemKeys,
                itemUrlKeys = recitationUrlKeys,
                firstItemFallback = "Open app to refresh",
                scheduleKey = KEY_RECITATION_SCHEDULE
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

class DailyPrayerTimesWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            DailyPrayerTimesWidgetContent()
        }
    }
}

class DailyPrayerTimesWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DailyPrayerTimesWidget()
}

class PrayerWidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_REFRESH_PRAYER_WIDGET) return

        CoroutineScope(Dispatchers.Main).launch {
            UpcomingPrayerWidget().updateAll(context.applicationContext)
            DailyPrayerTimesWidget().updateAll(context.applicationContext)
            scheduleNextPrayerWidgetRefresh(context.applicationContext)
        }
    }
}

class RecitationWidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_REFRESH_RECITATION_WIDGET) return

        CoroutineScope(Dispatchers.Main).launch {
            TodaysRecitationWidget().updateAll(context.applicationContext)
            DailyPrayerTimesWidget().updateAll(context.applicationContext)
            scheduleNextRecitationWidgetRefresh(context.applicationContext)
        }
    }
}

@Composable
private fun WidgetListContent(
    titleKey: String,
    titleFallback: String,
    itemKeys: List<String>,
    itemUrlKeys: List<String>,
    firstItemFallback: String,
    scheduleKey: String? = null
) {
    val context = LocalContext.current
    val data = context.widgetData()
    val items = data.scheduledWidgetItems(scheduleKey) ?: itemKeys.mapIndexedNotNull { index, key ->
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
        Spacer(GlanceModifier.height(8.dp))
        if (items.size == 1 && items.first().url.isBlank()) {
            Spacer(GlanceModifier.defaultWeight())
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
                    text = if (item.url.isNotBlank()) "${item.title}  ›" else item.title,
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
    val footer = prayer.secondaryText.ifBlank { prayer.location }

    WidgetSurface(clickable = true, contentPadding = 14) {
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = data.text(KEY_PRAYER_TITLE, "Next Prayer")
                    .replace("Upcoming", "Next")
                    .replace(" Prayer", ""),
                modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(
                    color = secondaryTextColor,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.Bold
                ),
                maxLines = 1
            )
            PrayerIconBadge(prayer.name, containerSizeDp = 24, iconSizeDp = 13)
        }
        Spacer(GlanceModifier.height(2.dp))
        Text(
            text = prayer.name,
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(
                color = primaryTextColor,
                fontSize = 16.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
        Spacer(GlanceModifier.height(8.dp))
        Text(
            text = prayer.time,
            style = TextStyle(
                color = bodyTextColor,
                fontSize = 25.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
        Spacer(GlanceModifier.defaultWeight())
        Text(
            text = footer,
            style = TextStyle(color = secondaryTextColor, fontSize = 10.sp),
            maxLines = 1
        )
    }
}

@Composable
private fun DailyPrayerTimesWidgetContent() {
    val context = LocalContext.current
    val data = context.widgetData()
    val prayers = data.dailyPrayerTimes()
    val location = data.text(KEY_PRAYER_LOCATION, "Location needed")
    val nextPrayer = data.nextPrayer()
    val countdown = nextPrayer.countdownText()
    val visiblePrayers = prayers.take(5)

    WidgetSurface(clickable = true, contentPadding = 10) {
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                modifier = GlanceModifier.defaultWeight(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Image(
                    provider = ImageProvider(R.drawable.ic_widget_location),
                    contentDescription = "Location",
                    modifier = GlanceModifier.size(11.dp),
                    colorFilter = ColorFilter.tint(secondaryTextColor)
                )
                Spacer(GlanceModifier.width(3.dp))
                Text(
                    text = location,
                    modifier = GlanceModifier.defaultWeight(),
                    style = TextStyle(
                        color = secondaryTextColor,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    maxLines = 1
                )
            }
            if (countdown.isNotBlank()) {
                Spacer(GlanceModifier.width(6.dp))
                Text(
                    text = countdown,
                    modifier = GlanceModifier.defaultWeight(),
                    style = TextStyle(
                        color = bodyTextColor,
                        fontSize = 11.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.End
                    ),
                    maxLines = 1
                )
            }
        }
        Spacer(GlanceModifier.defaultWeight())
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            visiblePrayers.forEachIndexed { index, prayer ->
                PrayerTimeColumn(prayer)
                if (index != visiblePrayers.lastIndex) {
                    Spacer(GlanceModifier.width(4.dp))
                }
            }
        }
        Spacer(GlanceModifier.defaultWeight())
    }
}

@Composable
private fun RowScope.PrayerTimeColumn(prayer: DailyPrayerTimeDisplay) {
    Column(
        modifier = GlanceModifier.defaultWeight(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        PrayerIconBadge(prayer.title, containerSizeDp = 25, iconSizeDp = 14)
        Spacer(GlanceModifier.height(4.dp))
        Text(
            text = prayer.title,
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(
                color = secondaryTextColor,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            ),
            maxLines = 1
        )
        Text(
            text = prayer.time,
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(
                color = bodyTextColor,
                fontSize = 10.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            ),
            maxLines = 1
        )
    }
}

@Composable
private fun PrayerIconBadge(
    prayerName: String,
    containerSizeDp: Int,
    iconSizeDp: Int
) {
    Box(
        modifier = GlanceModifier
            .size(containerSizeDp.dp)
            .background(iconBackgroundColor)
            .cornerRadius((containerSizeDp / 2).dp),
        contentAlignment = Alignment.Center
    ) {
        Image(
            provider = ImageProvider(prayerIconRes(prayerName)),
            contentDescription = prayerName.ifBlank { "Prayer" },
            modifier = GlanceModifier.size(iconSizeDp.dp),
            colorFilter = ColorFilter.tint(accentColor)
        )
    }
}

@Composable
private fun WidgetSurface(
    clickable: Boolean,
    clickUrl: String? = null,
    contentPadding: Int = 14,
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
        .padding(contentPadding.dp)

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
    val triggerAt = nextPrayer
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

fun scheduleNextRecitationWidgetRefresh(context: Context) {
    val triggerAt = context.widgetData().nextWidgetListScheduleEpochMillis(
        KEY_RECITATION_SCHEDULE
    ) ?: nextLocalMidnightMillis()
    if (triggerAt <= System.currentTimeMillis()) return

    val intent = Intent(context, RecitationWidgetRefreshReceiver::class.java).apply {
        action = ACTION_REFRESH_RECITATION_WIDGET
    }
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or (
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )
    val pendingIntent = PendingIntent.getBroadcast(context, 1, intent, flags)
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
    val url: String,
    val time: String = ""
)

private data class WidgetListScheduleEntry(
    val startEpochMillis: Long,
    val items: List<WidgetItem>
)

private fun android.content.SharedPreferences.scheduledWidgetItems(
    scheduleKey: String?
): List<WidgetItem>? {
    if (scheduleKey.isNullOrBlank()) return null

    val now = System.currentTimeMillis()
    return parseWidgetListSchedule(getString(scheduleKey, ""))
        .lastOrNull { it.startEpochMillis <= now }
        ?.items
        ?.takeIf { it.isNotEmpty() }
}

private fun android.content.SharedPreferences.nextWidgetListScheduleEpochMillis(
    scheduleKey: String
): Long? {
    val now = System.currentTimeMillis()
    return parseWidgetListSchedule(getString(scheduleKey, ""))
        .map { it.startEpochMillis }
        .filter { it > now }
        .minOrNull()
}

private fun parseWidgetListSchedule(rawSchedule: String?): List<WidgetListScheduleEntry> {
    if (rawSchedule.isNullOrBlank()) return emptyList()

    return try {
        val entries = JSONArray(rawSchedule)
        List(entries.length()) { index ->
            val entry = entries.getJSONObject(index)
            val rawItems = entry.optJSONArray("items") ?: JSONArray()
            val items = List(rawItems.length()) { itemIndex ->
                val rawItem = rawItems.getJSONObject(itemIndex)
                WidgetItem(
                    title = rawItem.optString("title", "").trim(),
                    url = rawItem.optString("url", "").trim(),
                    time = rawItem.optString("time", "").trim()
                )
            }.filter { it.title.isNotBlank() }

            WidgetListScheduleEntry(
                startEpochMillis = entry.optLong("start"),
                items = items
            )
        }
            .filter { it.startEpochMillis > 0L }
            .sortedBy { it.startEpochMillis }
    } catch (_: Exception) {
        emptyList()
    }
}

private fun nextLocalMidnightMillis(): Long {
    return Calendar.getInstance().apply {
        add(Calendar.DAY_OF_YEAR, 1)
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis
}

private fun Context.openUrlIntent(url: String): Intent {
    return openWidgetIntent(url)
}

private fun Context.openWidgetIntent(url: String?): Intent {
    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        ?: Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
        }

    return launchIntent.apply {
        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        url?.takeIf { it.isNotBlank() }?.let {
            putExtra(WIDGET_URL_EXTRA, it)
        }
    }
}

private fun android.content.SharedPreferences.text(key: String, fallback: String): String {
    return getString(key, fallback)?.takeIf { it.isNotBlank() } ?: fallback
}

private data class PrayerDisplay(
    val epochMillis: Long?,
    val name: String,
    val time: String,
    val location: String,
    val secondaryName: String,
    val secondaryTime: String
)

private val PrayerDisplay.secondaryText: String
    get() = if (secondaryName.isNotBlank() && secondaryTime.isNotBlank()) {
        "$secondaryName: $secondaryTime"
    } else {
        ""
    }

private fun PrayerDisplay.countdownText(nowMillis: Long = System.currentTimeMillis()): String {
    val targetMillis = epochMillis ?: return ""
    val remainingMillis = targetMillis - nowMillis
    if (remainingMillis <= 0L) return "$name now"

    val totalMinutes = ((remainingMillis + 59_999L) / 60_000L).coerceAtLeast(1L)
    val days = totalMinutes / (24L * 60L)
    val hours = (totalMinutes % (24L * 60L)) / 60L
    val minutes = totalMinutes % 60L
    val remaining = when {
        days > 0L && hours > 0L -> "${days}d ${hours}h"
        days > 0L -> "${days}d"
        hours > 0L && minutes > 0L -> "${hours}h ${minutes}m"
        hours > 0L -> "${hours}h"
        else -> "${minutes}m"
    }
    return "$name in $remaining"
}

private data class DailyPrayerTimeDisplay(
    val title: String,
    val time: String
)

private fun prayerIconRes(prayerName: String): Int {
    val name = prayerName.lowercase()
    return when {
        name.contains("fajr") -> R.drawable.ic_prayer_fajr
        name.contains("zuhr") || name.contains("dhuhr") || name.contains("dhohr") ->
            R.drawable.ic_prayer_zuhr
        name.contains("asr") -> R.drawable.ic_prayer_asr
        name.contains("maghrib") -> R.drawable.ic_prayer_maghrib
        name.contains("isha") -> R.drawable.ic_prayer_isha
        else -> R.drawable.ic_prayer_zuhr
    }
}

private data class PrayerEntry(
    val epochMillis: Long,
    val name: String,
    val time: String,
    val secondaryName: String,
    val secondaryTime: String
)

private fun android.content.SharedPreferences.nextPrayer(): PrayerDisplay {
    val location = text(KEY_PRAYER_LOCATION, "Location needed")
    val now = System.currentTimeMillis()
    val next = getString(KEY_PRAYER_SCHEDULE, "")
        ?.split(';')
        ?.mapNotNull { rawEntry ->
            val parts = rawEntry.split('|', limit = 6)
            if (parts.size != 4 && parts.size != 6) return@mapNotNull null
            val epochMillis = parts[0].toLongOrNull() ?: return@mapNotNull null
            PrayerEntry(
                epochMillis = epochMillis,
                name = parts[1],
                time = parts[2],
                secondaryName = parts.getOrNull(4).orEmpty(),
                secondaryTime = parts.getOrNull(5).orEmpty()
            )
        }
        ?.filter { it.epochMillis > now }
        ?.minByOrNull { it.epochMillis }

    if (next != null) {
        return PrayerDisplay(
            epochMillis = next.epochMillis,
            name = next.name,
            time = next.time,
            location = location,
            secondaryName = next.secondaryName,
            secondaryTime = next.secondaryTime
        )
    }

    return PrayerDisplay(
        epochMillis = null,
        name = text(KEY_PRAYER_NAME, "Prayer Times"),
        time = text(KEY_PRAYER_TIME, "Set location"),
        location = location,
        secondaryName = text(KEY_PRAYER_SECONDARY_NAME, ""),
        secondaryTime = text(KEY_PRAYER_SECONDARY_TIME, "")
    )
}

private fun android.content.SharedPreferences.dailyPrayerTimes(): List<DailyPrayerTimeDisplay> {
    val scheduledItems = scheduledWidgetItems(KEY_DAILY_PRAYER_SCHEDULE)
    val items = scheduledItems ?: dailyPrayerNameKeys.mapIndexedNotNull { index, key ->
        val title = text(key, if (index == 0) "Set location" else "")
        val time = text(dailyPrayerTimeKeys[index], if (index == 0) "Open app" else "")
        if (title.isBlank() && time.isBlank()) {
            null
        } else {
            WidgetItem(title = title, url = "", time = time)
        }
    }

    return items
        .take(5)
        .map { DailyPrayerTimeDisplay(title = it.title, time = it.time) }
}

private fun android.content.SharedPreferences.nextPrayerEpochMillis(): Long? {
    val now = System.currentTimeMillis()
    return getString(KEY_PRAYER_SCHEDULE, "")
        ?.split(';')
        ?.mapNotNull { rawEntry ->
            val parts = rawEntry.split('|', limit = 6)
            if (parts.size != 4 && parts.size != 6) return@mapNotNull null
            parts[0].toLongOrNull()
        }
        ?.filter { it > now }
        ?.minOrNull()
}
