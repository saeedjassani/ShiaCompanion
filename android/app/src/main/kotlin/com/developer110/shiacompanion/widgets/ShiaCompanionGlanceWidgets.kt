package com.developer110.shiacompanion.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.TypedValue
import android.widget.RemoteViews
import androidx.compose.runtime.Composable
import androidx.glance.ColorFilter
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.Action
import androidx.glance.action.ActionParameters
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.appwidget.AndroidRemoteViews
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.appWidgetBackground
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
import androidx.glance.layout.fillMaxHeight
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
import androidx.glance.unit.ColorProvider
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
private const val ACTION_REFRESH_CALENDAR_WIDGET =
    "com.developer110.shiacompanion.widgets.REFRESH_CALENDAR_WIDGET"

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
// Mirrors maxWidgetPrayerTimes in the Flutter app: the widest a user's
// Settings selection can ever be.
private const val MAX_DAILY_PRAYER_TIMES = 5
private val dailyPrayerNameKeys = (1..MAX_DAILY_PRAYER_TIMES).map { "sc_daily_prayer_name_$it" }
private val dailyPrayerTimeKeys = (1..MAX_DAILY_PRAYER_TIMES).map { "sc_daily_prayer_time_$it" }
private const val KEY_DAILY_PRAYER_SCHEDULE = "sc_daily_prayer_schedule"

private const val KEY_CALENDAR_DAYS = "sc_calendar_days"
private const val KEY_CALENDAR_EVENTS = "sc_calendar_events"
private const val KEY_CALENDAR_URL = "sc_calendar_url"
private const val DAY_MILLIS = 24L * 60L * 60L * 1000L

// Colours live in res/values(-night)/colors.xml so the shape drawables and the
// picker previews share them, and so API 31+ hosts resolve day/night themselves.
private val primaryTextColor = ColorProvider(R.color.widget_primary_text)
private val bodyTextColor = ColorProvider(R.color.widget_body_text)
private val secondaryTextColor = ColorProvider(R.color.widget_secondary_text)
private val accentColor = ColorProvider(R.color.widget_accent)
// events.json colours: 0 green, 1 red — the same reading as the Calendar page.
private val eventGreenColor = ColorProvider(R.color.widget_event_green)
private val eventRedColor = ColorProvider(R.color.widget_event_red)

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

class IslamicCalendarWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        // Re-armed on every render, not only when the app publishes: a reboot
        // drops alarms, and the launcher's own periodic update then puts the
        // midnight roll-over back without the app having to be opened.
        scheduleNextCalendarWidgetRefresh(context.applicationContext)
        provideContent {
            IslamicCalendarWidgetContent()
        }
    }
}

class IslamicCalendarWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = IslamicCalendarWidget()
}

class CalendarWidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_REFRESH_CALENDAR_WIDGET) return

        CoroutineScope(Dispatchers.Main).launch {
            IslamicCalendarWidget().updateAll(context.applicationContext)
            scheduleNextCalendarWidgetRefresh(context.applicationContext)
        }
    }
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
            items(items, itemId = { it.title.hashCode().toLong() }) { item ->
                // Every row in a Glance LazyColumn must carry a click action.
                // Android's RemoteViews ListView recycles rows by layout, and a
                // row that never had setOnClickFillInIntent() called on it can
                // still receive a stale click listener from a recycled row that
                // did — firing the trampoline Activity with no target intent
                // (IllegalArgumentException: "List adapter activity trampoline
                // invoked without specifying target intent"). Giving items
                // without a URL a no-op action keeps every row's fill-in intent
                // populated.
                val action: Action = item.url
                    .takeIf { it.isNotBlank() }
                    ?.let { actionStartActivity(context.openUrlIntent(it)) }
                    ?: actionRunCallback<NoOpWidgetAction>()
                Text(
                    text = if (item.url.isNotBlank()) "${item.title}  ›" else item.title,
                    modifier = GlanceModifier.clickable(action).fillMaxWidth().height(26.dp),
                    style = TextStyle(color = bodyTextColor, fontSize = 12.sp),
                    maxLines = 1
                )
            }
        }
    }
}

// The prayer widgets lay themselves out from the size the launcher actually
// gave them (SizeMode.Exact + LocalSize) rather than fixed dp/sp. Android
// cells vary a lot between launchers and screen aspect ratios - a "2x3" on a
// 21:9 phone is ~140x300dp - so a fixed layout either sits tiny in the top of
// a tall card or clips in a short one. Every size below is derived from the
// widget's dimensions and clamped to a readable range.

@Composable
private fun PrayerWidgetContent() {
    val context = LocalContext.current
    val data = context.widgetData()
    val upcoming = data.upcomingPrayers()
    val prayer = data.nextPrayer(upcoming)
    val later = upcoming.drop(1)
    val size = LocalSize.current
    val width = size.width.value
    val height = size.height.value
    val padding = when {
        minOf(width, height) >= 150f -> 16
        height < 80f -> 10
        else -> 14
    }
    val innerWidth = width - 2 * padding
    val innerHeight = height - 2 * padding
    val oneRow = innerHeight < HERO_CONTENT_HEIGHT * 0.7f
    val wide = !oneRow && width >= 230f && width >= height * 1.35f && later.isNotEmpty()

    WidgetSurface(clickable = true, contentPadding = padding) {
        if (wide) {
            // Side by side: the next prayer on the left, what follows it on the
            // right, split by a hairline.
            val heroWidth = innerWidth * 0.52f
            val scale = heroScale(heroWidth, innerHeight)
            Row(
                modifier = GlanceModifier.fillMaxSize(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(modifier = GlanceModifier.defaultWeight().fillMaxHeight()) {
                    NextPrayerHero(prayer, scale)
                    Spacer(GlanceModifier.defaultWeight())
                    PrayerFooter(prayer, scale)
                }
                Spacer(GlanceModifier.width(12.dp))
                VerticalDivider()
                Spacer(GlanceModifier.width(12.dp))
                val rowHeight = (22f * scale).coerceIn(20f, 30f)
                val rows = (innerHeight / rowHeight).toInt().coerceIn(1, 5)
                Column(
                    modifier = GlanceModifier.defaultWeight().fillMaxHeight(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    later.take(rows).forEach { LaterPrayerRow(it, scale, rowHeight) }
                }
            }
        } else if (oneRow) {
            // One row tall: too short for the stacked hero at its smallest scale.
            NextPrayerLine(prayer, innerWidth, innerHeight)
        } else {
            val scale = heroScale(innerWidth, innerHeight)
            NextPrayerHero(prayer, scale)
            // Tall cards (2x3 and up) have room below the hero: fill it with
            // the prayers that come after, instead of leaving it empty.
            val rowHeight = (22f * scale).coerceIn(20f, 28f)
            val listSpace = innerHeight - HERO_CONTENT_HEIGHT * scale - 20f
            val rows = (listSpace / rowHeight).toInt().coerceAtMost(4)
            if (later.isNotEmpty() && rows >= 2) {
                Spacer(GlanceModifier.defaultWeight())
                HorizontalDivider()
                Spacer(GlanceModifier.height(6.dp))
                later.take(rows).forEach { LaterPrayerRow(it, scale, rowHeight) }
            }
            Spacer(GlanceModifier.defaultWeight())
            PrayerFooter(prayer, scale)
        }
    }
}

// The hero column (label row, name, time, countdown, footer) at scale 1.0,
// and the width its widest line ("12:30 pm" at 30sp) needs.
private const val HERO_CONTENT_HEIGHT = 120f
private const val HERO_CONTENT_WIDTH = 122f

/**
 * 1.0 at the ~122x120dp content box of a 150dp iOS small widget. Height
 * matters as much as width: on Android 11 Launcher3 a 2x2 on a 21:9 phone is
 * only ~130x118dp, so scaling by width alone would clip the footer.
 */
private fun heroScale(innerWidth: Float, innerHeight: Float): Float =
    minOf(innerWidth / HERO_CONTENT_WIDTH, innerHeight / HERO_CONTENT_HEIGHT)
        .coerceIn(0.7f, 1.4f)

@Composable
private fun NextPrayerHero(prayer: PrayerDisplay, scale: Float) {
    val label = buildString {
        append(prayer.title)
        if (prayer.dateLabel.isNotBlank() && prayer.dateLabel != "Today") {
            append(" · ").append(prayer.dateLabel)
        }
    }
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(
                color = secondaryTextColor,
                fontSize = (11f * scale).sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
        val badge = (28f * scale).toInt()
        PrayerIconBadge(prayer.name, containerSizeDp = badge, iconSizeDp = badge * 15 / 28)
    }
    Spacer(GlanceModifier.height((4f * scale).dp))
    Text(
        text = prayer.name,
        modifier = GlanceModifier.fillMaxWidth(),
        style = TextStyle(
            color = primaryTextColor,
            fontSize = (17f * scale).sp,
            fontWeight = FontWeight.Bold
        ),
        maxLines = 1
    )
    if (prayer.epochMillis == null) {
        // No schedule yet: `time` is an instruction ("Set location"), not a
        // clock reading, so it gets body text rather than the display size.
        Spacer(GlanceModifier.height(4.dp))
        Text(
            text = prayer.time,
            style = TextStyle(color = bodyTextColor, fontSize = (13f * scale).sp),
            maxLines = 2
        )
        return
    }
    TimeText(prayer.time, sizeSp = 30f * scale, color = bodyTextColor)
    Countdown(prayer.epochMillis, prefix = "in", sizeSp = 12f * scale)
}

/** The 1-row Up Next: badge, name over countdown, then the time on the right. */
@Composable
private fun NextPrayerLine(prayer: PrayerDisplay, innerWidth: Float, innerHeight: Float) {
    val target = prayer.epochMillis
    val nameSp = (innerHeight * 0.3f).coerceIn(11f, 16f)
    val countdownSp = (nameSp * 0.8f).coerceAtLeast(10f)
    val showCountdown = target != null && innerHeight >= nameSp * 1.2f + countdownSp * 1.2f
    Row(
        modifier = GlanceModifier.fillMaxSize(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (innerWidth >= 120f) {
            val badge = (innerHeight * 0.8f).coerceIn(20f, 36f)
            PrayerIconBadge(prayer.name, containerSizeDp = badge.toInt(), iconSizeDp = (badge * 0.54f).toInt())
            Spacer(GlanceModifier.width(8.dp))
        }
        Column(modifier = GlanceModifier.defaultWeight()) {
            Text(
                text = prayer.name,
                style = TextStyle(
                    color = primaryTextColor,
                    fontSize = nameSp.sp,
                    fontWeight = FontWeight.Bold
                ),
                maxLines = 1
            )
            if (showCountdown && target != null) {
                Countdown(target, prefix = "in", sizeSp = countdownSp)
            }
        }
        Spacer(GlanceModifier.width(6.dp))
        if (target == null) {
            // No schedule yet: `time` is an instruction, not a clock reading.
            Text(
                text = prayer.time,
                style = TextStyle(color = bodyTextColor, fontSize = countdownSp.sp),
                maxLines = 1
            )
        } else {
            val timeSp = minOf(innerHeight * 0.55f, innerWidth / 6.5f).coerceIn(13f, 26f)
            TimeText(prayer.time, sizeSp = timeSp, color = bodyTextColor)
        }
    }
}

@Composable
private fun PrayerFooter(prayer: PrayerDisplay, scale: Float) {
    val secondary = prayer.secondaryText
    Row(verticalAlignment = Alignment.CenterVertically) {
        if (secondary.isBlank()) {
            Image(
                provider = ImageProvider(R.drawable.ic_widget_location),
                contentDescription = "Location",
                modifier = GlanceModifier.size((10f * scale).dp),
                colorFilter = ColorFilter.tint(secondaryTextColor)
            )
            Spacer(GlanceModifier.width(3.dp))
        }
        Text(
            text = secondary.ifBlank { prayer.location },
            style = TextStyle(color = secondaryTextColor, fontSize = (10.5f * scale).sp),
            maxLines = 1
        )
    }
}

@Composable
private fun LaterPrayerRow(prayer: PrayerEntry, scale: Float, rowHeight: Float) {
    val textSp = (11.5f * scale).coerceIn(10.5f, 14f)
    Row(
        modifier = GlanceModifier.fillMaxWidth().height(rowHeight.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Image(
            provider = ImageProvider(prayerIconRes(prayer.name)),
            contentDescription = prayer.name,
            modifier = GlanceModifier.size((textSp * 1.25f).dp),
            colorFilter = ColorFilter.tint(secondaryTextColor)
        )
        Spacer(GlanceModifier.width(6.dp))
        Text(
            text = prayer.name,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = bodyTextColor, fontSize = textSp.sp),
            maxLines = 1
        )
        TimeText(prayer.time, sizeSp = textSp, color = secondaryTextColor, suffixRatio = 0.78f)
    }
}

@Composable
private fun DailyPrayerTimesWidgetContent() {
    val context = LocalContext.current
    val data = context.widgetData()
    val upcoming = data.upcomingPrayers()
    val nextPrayer = data.nextPrayer(upcoming)
    val prayers = data.dailyPrayerTimes(upcoming)
    val location = data.text(KEY_PRAYER_LOCATION, "Location needed")
    val size = LocalSize.current
    val width = size.width.value
    val height = size.height.value
    val padding = if (height >= 150f) 16 else 12
    val innerWidth = width - 2 * padding
    val innerHeight = height - 2 * padding
    val hasTimes = prayers.any { it.time.isNotBlank() } && nextPrayer.epochMillis != null
    val isNext = { prayer: DailyPrayerTimeDisplay ->
        prayer.title == nextPrayer.name && prayer.time == nextPrayer.time
    }

    WidgetSurface(clickable = true, contentPadding = padding) {
        when {
            !hasTimes -> {
                LocationHeader(location, nextPrayer = null, sizeSp = 11f)
                Spacer(GlanceModifier.defaultWeight())
                Text(
                    text = listOf(nextPrayer.name, nextPrayer.time)
                        .filter { it.isNotBlank() }
                        .joinToString("\n"),
                    modifier = GlanceModifier.fillMaxWidth(),
                    style = TextStyle(
                        color = bodyTextColor,
                        fontSize = 13.sp,
                        textAlign = TextAlign.Center
                    ),
                    maxLines = 3
                )
                Spacer(GlanceModifier.defaultWeight())
            }
            // Narrow: columns would squeeze the times, so stack them.
            innerWidth < 210f -> {
                // At 3x2 there isn't height for the location and five
                // comfortable rows, so the rows win and the header goes.
                val showHeader = innerHeight - 22f >= prayers.size * 20f
                if (showHeader) {
                    val headerSp = (11f * (innerWidth / 150f)).coerceIn(10f, 12f)
                    LocationHeader(location, nextPrayer = null, sizeSp = headerSp)
                    Spacer(GlanceModifier.height(6.dp))
                }
                val listHeight = innerHeight - if (showHeader) 22f else 0f
                val rowHeight = (listHeight / prayers.size).coerceIn(15f, 40f)
                val scale = (rowHeight / 26f).coerceIn(0.75f, 1.3f)
                prayers.forEach { prayer ->
                    DailyPrayerRow(prayer, isNext(prayer), scale, rowHeight)
                }
                Spacer(GlanceModifier.defaultWeight())
            }
            // Tall: the next prayer as a hero above the full row (the 4x3/5x3
            // sizes, which otherwise leave half the card empty).
            innerHeight >= 170f -> {
                val scale = minOf(innerWidth / 300f, innerHeight / 210f).coerceIn(0.9f, 1.35f)
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    LocationLabel(location, sizeSp = 11f * scale, modifier = GlanceModifier.defaultWeight())
                    Spacer(GlanceModifier.width(8.dp))
                    DateText(sizeSp = 11f * scale)
                }
                Spacer(GlanceModifier.defaultWeight())
                Row(
                    modifier = GlanceModifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val badge = (44f * scale).toInt()
                    PrayerIconBadge(nextPrayer.name, containerSizeDp = badge, iconSizeDp = badge / 2)
                    Spacer(GlanceModifier.width(12.dp))
                    Column(modifier = GlanceModifier.defaultWeight()) {
                        Text(
                            text = nextPrayer.name,
                            style = TextStyle(
                                color = primaryTextColor,
                                fontSize = (19f * scale).sp,
                                fontWeight = FontWeight.Bold
                            ),
                            maxLines = 1
                        )
                        Countdown(nextPrayer.epochMillis!!, prefix = "in", sizeSp = 12f * scale)
                    }
                    Spacer(GlanceModifier.width(8.dp))
                    TimeText(nextPrayer.time, sizeSp = 30f * scale, color = bodyTextColor)
                }
                Spacer(GlanceModifier.defaultWeight())
                HorizontalDivider()
                Spacer(GlanceModifier.defaultWeight())
                val columnHeight = innerHeight * 0.42f
                PrayerColumnsRow(prayers, isNext, innerWidth, columnHeight)
            }
            else -> {
                val headerSp = (11f * (innerHeight / 100f)).coerceIn(10.5f, 12.5f)
                LocationHeader(location, nextPrayer, headerSp)
                Spacer(GlanceModifier.defaultWeight())
                PrayerColumnsRow(prayers, isNext, innerWidth, innerHeight - headerSp * 1.6f - 6f)
                Spacer(GlanceModifier.defaultWeight())
            }
        }
    }
}

/** Location on the left and, when [nextPrayer] is given, its live countdown on the right. */
@Composable
private fun LocationHeader(location: String, nextPrayer: PrayerDisplay?, sizeSp: Float) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        LocationLabel(location, sizeSp, GlanceModifier.defaultWeight())
        val target = nextPrayer?.epochMillis
        if (nextPrayer != null && target != null) {
            Spacer(GlanceModifier.width(6.dp))
            Countdown(target, prefix = "${nextPrayer.name} in", sizeSp = sizeSp)
        }
    }
}

@Composable
private fun LocationLabel(location: String, sizeSp: Float, modifier: GlanceModifier) {
    Row(modifier = modifier, verticalAlignment = Alignment.CenterVertically) {
        Image(
            provider = ImageProvider(R.drawable.ic_widget_location),
            contentDescription = "Location",
            modifier = GlanceModifier.size(sizeSp.dp),
            colorFilter = ColorFilter.tint(secondaryTextColor)
        )
        Spacer(GlanceModifier.width(3.dp))
        Text(
            text = location,
            style = TextStyle(
                color = secondaryTextColor,
                fontSize = sizeSp.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
    }
}

@Composable
private fun PrayerColumnsRow(
    prayers: List<DailyPrayerTimeDisplay>,
    isNext: (DailyPrayerTimeDisplay) -> Boolean,
    innerWidth: Float,
    columnHeight: Float
) {
    val spacing = 4
    val count = prayers.size.coerceAtLeast(1)
    val columnWidth = (innerWidth - spacing * (count - 1)) / count
    // Whichever runs out first - the column's width or the card's height -
    // sets the size, so a short wide card and a tall narrow one both fit.
    val badge = minOf(columnWidth * 0.62f, columnHeight * 0.42f).coerceIn(22f, 44f)
    val timeSp = minOf((columnWidth - 8f) / 3.7f, badge * 0.42f).coerceIn(9.5f, 17f)
    val nameSp = minOf((columnWidth - 6f) / 4.6f, timeSp * 0.85f).coerceIn(9f, 13f)
    val verticalPadding = if (columnHeight >= 90f) 8 else 5

    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        prayers.forEachIndexed { index, prayer ->
            val next = isNext(prayer)
            Column(
                modifier = GlanceModifier
                    .defaultWeight()
                    .let { if (next) it.background(ImageProvider(R.drawable.widget_highlight)) else it }
                    .padding(vertical = verticalPadding.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                PrayerIconBadge(
                    prayer.title,
                    containerSizeDp = badge.toInt(),
                    iconSizeDp = (badge * 0.54f).toInt()
                )
                Spacer(GlanceModifier.height((badge * 0.16f).dp))
                Text(
                    text = prayer.title,
                    modifier = GlanceModifier.fillMaxWidth(),
                    style = TextStyle(
                        color = if (next) accentColor else secondaryTextColor,
                        fontSize = nameSp.sp,
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    ),
                    maxLines = 1
                )
                TimeText(
                    prayer.time,
                    sizeSp = timeSp,
                    color = if (next) primaryTextColor else bodyTextColor,
                    modifier = GlanceModifier.fillMaxWidth(),
                    centered = true
                )
            }
            if (index != prayers.lastIndex) {
                Spacer(GlanceModifier.width(spacing.dp))
            }
        }
    }
}

@Composable
private fun DailyPrayerRow(
    prayer: DailyPrayerTimeDisplay,
    isNext: Boolean,
    scale: Float,
    rowHeight: Float
) {
    val textSp = 12f * scale
    Row(
        modifier = GlanceModifier
            .fillMaxWidth()
            .height(rowHeight.dp)
            .let { if (isNext) it.background(ImageProvider(R.drawable.widget_highlight)) else it }
            .padding(horizontal = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        val badge = (rowHeight * 0.8f).coerceIn(12f, 28f)
        PrayerIconBadge(prayer.title, containerSizeDp = badge.toInt(), iconSizeDp = (badge * 0.56f).toInt())
        Spacer(GlanceModifier.width(8.dp))
        Text(
            text = prayer.title,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(
                color = if (isNext) accentColor else bodyTextColor,
                fontSize = textSp.sp,
                fontWeight = if (isNext) FontWeight.Bold else FontWeight.Medium
            ),
            maxLines = 1
        )
        TimeText(prayer.time, sizeSp = textSp, color = if (isNext) primaryTextColor else bodyTextColor, suffixRatio = 0.78f)
    }
}

/**
 * A clock reading with its am/pm marker set smaller and baseline-aligned, the
 * way a display time reads on iOS. Glance Text has no spans, so the marker is a
 * second Text nudged up by the difference in the two sizes' descents.
 */
@Composable
private fun TimeText(
    time: String,
    sizeSp: Float,
    color: ColorProvider,
    modifier: GlanceModifier = GlanceModifier,
    centered: Boolean = false,
    suffixRatio: Float = 0.5f
) {
    val (clock, marker) = splitClockTime(time)
    val markerSp = sizeSp * suffixRatio
    Row(
        modifier = modifier,
        horizontalAlignment = if (centered) Alignment.CenterHorizontally else Alignment.Start,
        verticalAlignment = Alignment.Bottom
    ) {
        Text(
            text = clock,
            style = TextStyle(color = color, fontSize = sizeSp.sp, fontWeight = FontWeight.Bold),
            maxLines = 1
        )
        if (marker.isNotEmpty()) {
            Spacer(GlanceModifier.width((sizeSp * 0.1f).coerceAtLeast(1.5f).dp))
            Text(
                text = marker,
                modifier = GlanceModifier.padding(bottom = ((sizeSp - markerSp) * 0.26f).dp),
                style = TextStyle(color = color, fontSize = markerSp.sp, fontWeight = FontWeight.Bold),
                maxLines = 1
            )
        }
    }
}

private val clockTimePattern = Regex("""^(.*?\d)\s*([AaPp]\.?\s?[Mm]\.?)$""")

private fun splitClockTime(time: String): Pair<String, String> {
    val match = clockTimePattern.find(time.trim()) ?: return time to ""
    return match.groupValues[1] to match.groupValues[2].replace(".", "").replace(" ", "").lowercase()
}

/**
 * "[prefix] 1:23:45", ticking. A Chronometer in counting-down mode, embedded
 * as RemoteViews: the launcher advances it every second with no widget
 * updates, which Glance's own Text can't do.
 */
@Composable
private fun Countdown(targetEpochMillis: Long, prefix: String, sizeSp: Float) {
    val context = LocalContext.current
    val views = RemoteViews(context.packageName, R.layout.widget_countdown).apply {
        val base = SystemClock.elapsedRealtime() + (targetEpochMillis - System.currentTimeMillis())
        setChronometer(R.id.widget_countdown, base, null, true)
        setChronometerCountDown(R.id.widget_countdown, true)
        setTextViewTextSize(R.id.widget_countdown, TypedValue.COMPLEX_UNIT_SP, sizeSp)
    }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(
            text = prefix,
            style = TextStyle(color = accentColor, fontSize = sizeSp.sp, fontWeight = FontWeight.Bold),
            maxLines = 1
        )
        Spacer(GlanceModifier.width(3.dp))
        AndroidRemoteViews(views)
    }
}

@Composable
private fun DateText(sizeSp: Float) {
    val context = LocalContext.current
    val views = RemoteViews(context.packageName, R.layout.widget_date).apply {
        setTextViewTextSize(R.id.widget_date, TypedValue.COMPLEX_UNIT_SP, sizeSp)
    }
    AndroidRemoteViews(views)
}

@Composable
private fun HorizontalDivider() {
    Box(
        modifier = GlanceModifier
            .fillMaxWidth()
            .height(1.dp)
            .background(ColorProvider(R.color.widget_divider))
    ) {}
}

@Composable
private fun VerticalDivider() {
    Box(
        modifier = GlanceModifier
            .width(1.dp)
            .fillMaxHeight()
            .background(ColorProvider(R.color.widget_divider))
    ) {}
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
            .background(ImageProvider(R.drawable.widget_icon_badge)),
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
    // GlanceModifier.cornerRadius() is a no-op below API 31, so the rounded
    // surface comes from a shape drawable instead of a flat colour + radius.
    val modifier = GlanceModifier
        .fillMaxSize()
        .appWidgetBackground()
        .background(ImageProvider(R.drawable.widget_surface))
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

fun scheduleNextCalendarWidgetRefresh(context: Context) {
    // A moment past midnight rather than on it, so the render lands on the new
    // day's entry instead of racing the boundary.
    val triggerAt = nextLocalMidnightMillis() + 5_000L

    val intent = Intent(context, CalendarWidgetRefreshReceiver::class.java).apply {
        action = ACTION_REFRESH_CALENDAR_WIDGET
    }
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or (
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )
    val pendingIntent = PendingIntent.getBroadcast(context, 2, intent, flags)
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

/**
 * Does nothing. Used so every row in a widget's LazyColumn has a click action
 * (see the comment at its usage site) even when that row has no URL to open.
 */
class NoOpWidgetAction : ActionCallback {
    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        // Intentionally empty.
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
    val title: String,
    val name: String,
    val time: String,
    val dateLabel: String,
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

private data class DailyPrayerTimeDisplay(
    val title: String,
    val time: String
)

private fun prayerIconRes(prayerName: String): Int {
    val name = prayerName.lowercase()
    return when {
        name.contains("fajr") -> R.drawable.ic_prayer_fajr
        name.contains("sunrise") -> R.drawable.ic_prayer_sunrise
        name.contains("zuhr") || name.contains("dhuhr") || name.contains("dhohr") ->
            R.drawable.ic_prayer_zuhr
        name.contains("asr") -> R.drawable.ic_prayer_asr
        name.contains("sunset") -> R.drawable.ic_prayer_sunset
        name.contains("maghrib") -> R.drawable.ic_prayer_maghrib
        name.contains("isha") -> R.drawable.ic_prayer_isha
        name.contains("midnight") -> R.drawable.ic_prayer_midnight
        else -> R.drawable.ic_prayer_zuhr
    }
}

private data class PrayerEntry(
    val epochMillis: Long,
    val name: String,
    val time: String,
    val dateLabel: String,
    val secondaryName: String,
    val secondaryTime: String
)

/** The flat, chronological schedule Flutter writes: `epoch|name|time|dateLabel[|secondaryName|secondaryTime]`. */
private fun android.content.SharedPreferences.prayerSchedule(): List<PrayerEntry> {
    return getString(KEY_PRAYER_SCHEDULE, "")
        ?.split(';')
        ?.mapNotNull { rawEntry ->
            val parts = rawEntry.split('|', limit = 6)
            if (parts.size != 4 && parts.size != 6) return@mapNotNull null
            val epochMillis = parts[0].toLongOrNull() ?: return@mapNotNull null
            PrayerEntry(
                epochMillis = epochMillis,
                name = parts[1],
                time = parts[2],
                dateLabel = parts[3],
                secondaryName = parts.getOrNull(4).orEmpty(),
                secondaryTime = parts.getOrNull(5).orEmpty()
            )
        }
        ?.sortedBy { it.epochMillis }
        .orEmpty()
}

private fun android.content.SharedPreferences.upcomingPrayers(
    now: Long = System.currentTimeMillis()
): List<PrayerEntry> = prayerSchedule().filter { it.epochMillis > now }

private fun android.content.SharedPreferences.nextPrayer(
    upcoming: List<PrayerEntry> = upcomingPrayers()
): PrayerDisplay {
    val location = text(KEY_PRAYER_LOCATION, "Location needed")
    val title = text(KEY_PRAYER_TITLE, "Up Next")
        .replace("Upcoming", "Next")
        .replace(" Prayer", "")
    val next = upcoming.firstOrNull()

    if (next != null) {
        return PrayerDisplay(
            epochMillis = next.epochMillis,
            title = title,
            name = next.name,
            time = next.time,
            dateLabel = next.dateLabel,
            location = location,
            secondaryName = next.secondaryName,
            secondaryTime = next.secondaryTime
        )
    }

    return PrayerDisplay(
        epochMillis = null,
        title = title,
        name = text(KEY_PRAYER_NAME, "Prayer Times"),
        time = text(KEY_PRAYER_TIME, "Set location"),
        dateLabel = "",
        location = location,
        secondaryName = text(KEY_PRAYER_SECONDARY_NAME, ""),
        secondaryTime = text(KEY_PRAYER_SECONDARY_TIME, "")
    )
}

private fun android.content.SharedPreferences.dailyPrayerTimes(
    upcoming: List<PrayerEntry> = upcomingPrayers()
): List<DailyPrayerTimeDisplay> {
    // Same order of preference as the iOS widget: the flat prayer schedule
    // filtered for "now" can never land between two pre-baked boundaries
    // and show a stale window, so use it first; then the rolling JSON
    // schedule; then the frozen per-slot keys. How many to take is the
    // user's Settings selection, which the frozen keys are always written to.
    val frozenItems = dailyPrayerNameKeys.mapIndexedNotNull { index, key ->
        val title = text(key, if (index == 0) "Set location" else "")
        val time = text(dailyPrayerTimeKeys[index], if (index == 0) "Open app" else "")
        if (title.isBlank() && time.isBlank()) {
            null
        } else {
            WidgetItem(title = title, url = "", time = time)
        }
    }
    val selectedCount = frozenItems.size.takeIf { it > 0 } ?: MAX_DAILY_PRAYER_TIMES
    val fromSchedule = upcoming
        .take(selectedCount)
        .map { WidgetItem(title = it.name, url = "", time = it.time) }
    val items = fromSchedule.takeIf { it.isNotEmpty() }
        ?: scheduledWidgetItems(KEY_DAILY_PRAYER_SCHEDULE)
        ?: frozenItems

    return items
        .take(MAX_DAILY_PRAYER_TIMES)
        .map { DailyPrayerTimeDisplay(title = it.title, time = it.time) }
}

private fun android.content.SharedPreferences.nextPrayerEpochMillis(): Long? =
    upcomingPrayers().firstOrNull()?.epochMillis

// Islamic calendar

private data class CalendarDay(
    val startEpochMillis: Long,
    val day: Int,
    val month: String,
    val year: Int,
    val event: String,
    val color: Int
)

private data class CalendarEvent(
    val startEpochMillis: Long,
    val hijri: String,
    val title: String,
    val color: Int
)

/**
 * The hijri date for today, or null when the app has never published one or
 * the published run of days has been used up. Each entry starts at local
 * midnight and the last one that has started is today, the same rule the
 * list widgets' schedules follow.
 */
private fun android.content.SharedPreferences.currentCalendarDay(now: Long): CalendarDay? {
    val day = calendarDays().lastOrNull { it.startEpochMillis <= now } ?: return null
    // A day is at most 25 hours long (DST); past that the run has ended and the
    // last entry is no longer today.
    return day.takeIf { now - it.startEpochMillis < DAY_MILLIS + 60L * 60L * 1000L }
}

private fun android.content.SharedPreferences.calendarDays(): List<CalendarDay> {
    val raw = getString(KEY_CALENDAR_DAYS, "")
    if (raw.isNullOrBlank()) return emptyList()

    return try {
        val entries = JSONArray(raw)
        List(entries.length()) { index ->
            val entry = entries.getJSONObject(index)
            CalendarDay(
                startEpochMillis = entry.optLong("start"),
                day = entry.optInt("day"),
                month = entry.optString("month", "").trim(),
                year = entry.optInt("year"),
                event = entry.optString("event", "").trim(),
                color = entry.optInt("color", -1)
            )
        }
            .filter { it.startEpochMillis > 0L && it.day > 0 }
            .sortedBy { it.startEpochMillis }
    } catch (_: Exception) {
        emptyList()
    }
}

private fun android.content.SharedPreferences.calendarEvents(): List<CalendarEvent> {
    val raw = getString(KEY_CALENDAR_EVENTS, "")
    if (raw.isNullOrBlank()) return emptyList()

    return try {
        val entries = JSONArray(raw)
        List(entries.length()) { index ->
            val entry = entries.getJSONObject(index)
            CalendarEvent(
                startEpochMillis = entry.optLong("start"),
                hijri = entry.optString("hijri", "").trim(),
                title = entry.optString("title", "").trim(),
                color = entry.optInt("color", -1)
            )
        }
            .filter { it.startEpochMillis > 0L && it.title.isNotBlank() }
            .sortedBy { it.startEpochMillis }
    } catch (_: Exception) {
        emptyList()
    }
}

private fun startOfLocalDayMillis(epochMillis: Long): Long {
    return Calendar.getInstance().apply {
        timeInMillis = epochMillis
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }.timeInMillis
}

/** "Today", "Tomorrow" or "in 12 days". Rounded, so a DST day still counts as one. */
private fun relativeDayLabel(startEpochMillis: Long, todayStart: Long): String {
    val days = Math.round((startEpochMillis - todayStart).toDouble() / DAY_MILLIS).toInt()
    return when {
        days <= 0 -> "Today"
        days == 1 -> "Tomorrow"
        else -> "in $days days"
    }
}

private fun calendarEventColor(code: Int): ColorProvider = when (code) {
    0 -> eventGreenColor
    1 -> eventRedColor
    else -> accentColor
}

@Composable
private fun IslamicCalendarWidgetContent() {
    val context = LocalContext.current
    val data = context.widgetData()
    val now = System.currentTimeMillis()
    val todayStart = startOfLocalDayMillis(now)
    val tomorrowStart = nextLocalMidnightMillis()
    val today = data.currentCalendarDay(now)
    // Today's event is already on the date itself, so the list is what follows.
    val upcoming = data.calendarEvents().filter {
        it.startEpochMillis >= if (today == null) todayStart else tomorrowStart
    }
    val url = data.text(KEY_CALENDAR_URL, "").takeIf { it.isNotBlank() }
    val size = LocalSize.current
    val width = size.width.value
    val height = size.height.value
    val padding = if (minOf(width, height) >= 150f) 16 else 12
    val innerWidth = width - 2 * padding
    val innerHeight = height - 2 * padding

    WidgetSurface(clickable = true, clickUrl = url, contentPadding = padding) {
        if (today == null) {
            Text(
                text = "Islamic Calendar",
                style = TextStyle(
                    color = primaryTextColor,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                ),
                maxLines = 1
            )
            Spacer(GlanceModifier.defaultWeight())
            Text(
                text = "Open app to refresh",
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

        val wide = width >= 250f && height < 170f && upcoming.isNotEmpty()
        if (wide) {
            // Side by side, like the Up Next widget: the date on the left, what
            // is coming up on the right.
            val scale = minOf(innerWidth / 300f, innerHeight / 100f).coerceIn(0.85f, 1.2f)
            val rowHeight = (22f * scale).coerceIn(18f, 28f)
            val rows = (innerHeight / rowHeight).toInt().coerceIn(1, 5)
            Row(
                modifier = GlanceModifier.fillMaxSize(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(
                    modifier = GlanceModifier.defaultWeight().fillMaxHeight(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    HijriDateHero(today, scale, eventLines = 2)
                }
                Spacer(GlanceModifier.width(12.dp))
                VerticalDivider()
                Spacer(GlanceModifier.width(12.dp))
                Column(
                    modifier = GlanceModifier.defaultWeight().fillMaxHeight(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    upcoming.take(rows).forEach {
                        CalendarEventRow(it, todayStart, scale, rowHeight)
                    }
                }
            }
        } else {
            val scale = minOf(innerWidth / 200f, innerHeight / 130f).coerceIn(0.8f, 1.25f)
            val rowHeight = (22f * scale).coerceIn(18f, 28f)
            val eventLines = if (innerHeight >= 150f) 2 else 1
            val heroHeight = (58f + if (today.event.isNotBlank()) 17f * eventLines else 0f) * scale
            val rows = ((innerHeight - heroHeight - 14f) / rowHeight).toInt().coerceIn(0, 6)
            // The hero and the rows each get a Column of their own: a Glance
            // Row or Column takes at most ten children, and the two together
            // can come to more than that on a tall widget.
            Column(modifier = GlanceModifier.fillMaxWidth()) {
                HijriDateHero(today, scale, eventLines)
            }
            if (upcoming.isNotEmpty() && rows >= 1) {
                Spacer(GlanceModifier.defaultWeight())
                HorizontalDivider()
                Spacer(GlanceModifier.height(4.dp))
                Column(modifier = GlanceModifier.fillMaxWidth()) {
                    upcoming.take(rows).forEach {
                        CalendarEventRow(it, todayStart, scale, rowHeight)
                    }
                }
            }
            Spacer(GlanceModifier.defaultWeight())
        }
    }
}

/** The hijri day large, its month and year beside it, today's Gregorian date and event below. */
@Composable
private fun HijriDateHero(day: CalendarDay, scale: Float, eventLines: Int) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = day.day.toString(),
            style = TextStyle(
                color = accentColor,
                fontSize = (32f * scale).sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
        Spacer(GlanceModifier.width(8.dp))
        Column(modifier = GlanceModifier.defaultWeight()) {
            Text(
                text = day.month,
                style = TextStyle(
                    color = primaryTextColor,
                    fontSize = (14f * scale).sp,
                    fontWeight = FontWeight.Bold
                ),
                maxLines = 1
            )
            Text(
                text = "${day.year} AH",
                style = TextStyle(
                    color = secondaryTextColor,
                    fontSize = (11f * scale).sp,
                    fontWeight = FontWeight.Bold
                ),
                maxLines = 1
            )
        }
    }
    DateText(sizeSp = 11f * scale)
    if (day.event.isNotBlank()) {
        Spacer(GlanceModifier.height(4.dp))
        Row(verticalAlignment = Alignment.Top) {
            Text(
                text = "●",
                style = TextStyle(color = calendarEventColor(day.color), fontSize = (10f * scale).sp),
                maxLines = 1
            )
            Spacer(GlanceModifier.width(5.dp))
            Text(
                text = day.event,
                style = TextStyle(
                    color = bodyTextColor,
                    fontSize = (12f * scale).sp,
                    fontWeight = FontWeight.Bold
                ),
                maxLines = eventLines
            )
        }
    }
}

@Composable
private fun CalendarEventRow(
    event: CalendarEvent,
    todayStart: Long,
    scale: Float,
    rowHeight: Float
) {
    Row(
        modifier = GlanceModifier.fillMaxWidth().height(rowHeight.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "●",
            style = TextStyle(color = calendarEventColor(event.color), fontSize = (9f * scale).sp),
            maxLines = 1
        )
        Spacer(GlanceModifier.width(6.dp))
        Text(
            text = event.title,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(color = bodyTextColor, fontSize = (12f * scale).sp),
            maxLines = 1
        )
        Spacer(GlanceModifier.width(6.dp))
        Text(
            text = relativeDayLabel(event.startEpochMillis, todayStart),
            style = TextStyle(
                color = secondaryTextColor,
                fontSize = (11f * scale).sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
    }
}
