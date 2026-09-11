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
import androidx.glance.LocalSize
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionStartActivity
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
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpSize
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

// Colours live in res/values(-night)/colors.xml so the shape drawables and the
// picker previews share them, and so API 31+ hosts resolve day/night themselves.
private val primaryTextColor = ColorProvider(R.color.widget_primary_text)
private val bodyTextColor = ColorProvider(R.color.widget_body_text)
private val secondaryTextColor = ColorProvider(R.color.widget_secondary_text)
private val accentColor = ColorProvider(R.color.widget_accent)

// Size buckets for SizeMode.Responsive. Glance builds one layout per bucket and
// the host swaps between them as the user resizes, so every shape gets type and
// spacing tuned for it instead of the 4x2 layout stretched to fit. SizeMode.Exact
// reports the host's raw size options below API 31, where those options are the
// stale portrait/landscape hints rather than the widget's real size - that is
// what made these widgets lay out at the wrong proportions on older launchers.
private val listWidgetSizes = setOf(
    DpSize(150.dp, 68.dp),
    DpSize(250.dp, 110.dp),
    DpSize(250.dp, 260.dp),
    DpSize(330.dp, 110.dp),
    DpSize(330.dp, 260.dp)
)

private val prayerWidgetSizes = setOf(
    DpSize(100.dp, 48.dp),
    DpSize(110.dp, 110.dp),
    DpSize(110.dp, 150.dp),
    DpSize(180.dp, 110.dp),
    DpSize(180.dp, 200.dp)
)

// The daily widget's row of five prayer columns is what sets its narrowest
// useful width, so it grows rather than shrinks: minResizeWidth in
// res/xml/daily_prayer_widget_info.xml matches this smallest bucket.
private val dailyPrayerWidgetSizes = setOf(
    DpSize(250.dp, 100.dp),
    DpSize(250.dp, 200.dp),
    DpSize(330.dp, 110.dp),
    DpSize(330.dp, 260.dp)
)

class FavoritesWidget : GlanceAppWidget() {
    override val sizeMode: SizeMode = SizeMode.Responsive(listWidgetSizes)

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
    override val sizeMode: SizeMode = SizeMode.Responsive(listWidgetSizes)

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
    override val sizeMode: SizeMode = SizeMode.Responsive(prayerWidgetSizes)

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
    override val sizeMode: SizeMode = SizeMode.Responsive(dailyPrayerWidgetSizes)

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
    val size = LocalSize.current
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

    // A one-row-tall widget has no height to spare for the usual title and
    // 26dp rows, and a wide one can afford larger type; both read as cramped or
    // stretched when a single set of sizes is used everywhere.
    val short = size.height < 84.dp
    val wide = size.width >= 300.dp
    val titleFontSize = if (short) 13 else if (wide) 17 else 16
    val itemFontSize = if (wide) 14 else 12
    val rowHeightDp = when {
        short -> 22
        size.height >= 260.dp -> 30
        else -> 26
    }

    WidgetSurface(clickable = false, contentPadding = if (short) 10 else 14) {
        Text(
            text = data.text(titleKey, titleFallback),
            style = TextStyle(
                color = primaryTextColor,
                fontSize = titleFontSize.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
        Spacer(GlanceModifier.height(if (short) 4.dp else 8.dp))
        if (items.size == 1 && items.first().url.isBlank()) {
            Spacer(GlanceModifier.defaultWeight())
            Text(
                text = items.first().title,
                modifier = GlanceModifier.fillMaxWidth(),
                style = TextStyle(
                    color = bodyTextColor,
                    fontSize = itemFontSize.sp,
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
                    modifier = modifier.fillMaxWidth().height(rowHeightDp.dp),
                    style = TextStyle(color = bodyTextColor, fontSize = itemFontSize.sp),
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
private fun PrayerWidgetContent() {
    val context = LocalContext.current
    val size = LocalSize.current
    val data = context.widgetData()
    val prayer = data.nextPrayer()
    val footer = prayer.secondaryText.ifBlank { prayer.location }

    // Resized down to a single row there is no room for the stacked card, so
    // swap in a one-line layout rather than clipping the stack.
    if (size.height < 84.dp) {
        WidgetSurface(clickable = true, contentPadding = 10) {
            Row(
                modifier = GlanceModifier.fillMaxSize(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                PrayerIconBadge(prayer.name, containerSizeDp = 22, iconSizeDp = 12)
                Spacer(GlanceModifier.width(7.dp))
                Text(
                    text = prayer.name,
                    modifier = GlanceModifier.defaultWeight(),
                    style = TextStyle(
                        color = primaryTextColor,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    maxLines = 1
                )
                Spacer(GlanceModifier.width(6.dp))
                Text(
                    text = prayer.time,
                    style = TextStyle(
                        color = bodyTextColor,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    maxLines = 1
                )
            }
        }
        return
    }

    // Glance has no equivalent of iOS's minimumScaleFactor, so the type steps up
    // with the placed size instead of a 2x2 layout floating in a 4x4 cell.
    val timeFontSize = when {
        size.height >= 170.dp -> 34
        size.height >= 130.dp -> 29
        else -> 25
    }
    val nameFontSize = when {
        size.height >= 170.dp -> 20
        size.height >= 130.dp -> 18
        else -> 16
    }
    val roomy = size.width >= 160.dp
    val badgeSizeDp = if (roomy) 30 else 24

    WidgetSurface(clickable = true, contentPadding = if (roomy) 16 else 14) {
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = data.text(KEY_PRAYER_TITLE, "Up Next")
                    .replace("Upcoming", "Next")
                    .replace(" Prayer", ""),
                modifier = GlanceModifier.defaultWeight(),
                style = TextStyle(
                    color = secondaryTextColor,
                    fontSize = if (roomy) 12.sp else 11.sp,
                    fontWeight = FontWeight.Bold
                ),
                maxLines = 1
            )
            PrayerIconBadge(
                prayer.name,
                containerSizeDp = badgeSizeDp,
                iconSizeDp = badgeSizeDp - 11
            )
        }
        Spacer(GlanceModifier.height(2.dp))
        Text(
            text = prayer.name,
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(
                color = primaryTextColor,
                fontSize = nameFontSize.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
        Spacer(GlanceModifier.height(8.dp))
        Text(
            text = prayer.time,
            style = TextStyle(
                color = bodyTextColor,
                fontSize = timeFontSize.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
        Spacer(GlanceModifier.defaultWeight())
        Text(
            text = footer,
            style = TextStyle(
                color = secondaryTextColor,
                fontSize = if (roomy) 11.sp else 10.sp
            ),
            maxLines = 1
        )
    }
}

@Composable
private fun DailyPrayerTimesWidgetContent() {
    val context = LocalContext.current
    val size = LocalSize.current
    val data = context.widgetData()
    val prayers = data.dailyPrayerTimes()
    val location = data.text(KEY_PRAYER_LOCATION, "Location needed")
    val nextPrayer = data.nextPrayer()
    val countdown = nextPrayer.countdownText()
    // The user's selection tops out at MAX_DAILY_PRAYER_TIMES (5, same as the
    // home screen card), so this is a safety clamp rather than the thing that
    // decides the count.
    val visiblePrayers = prayers.take(MAX_DAILY_PRAYER_TIMES)
    val hasPrayerTimes = visiblePrayers.any { it.time.isNotBlank() }
    val columnSpacingDp = 4
    val contentPaddingDp = if (size.width >= 300.dp) 12 else 10
    val columnWidthDp = (
        size.width.value - 2 * contentPaddingDp -
            columnSpacingDp * (visiblePrayers.size - 1).coerceAtLeast(0)
        ) / visiblePrayers.size.coerceAtLeast(1)
    // Stretched tall, a single row of columns leaves a band of empty card, so
    // the prayers reflow into one line each - but only once every selected
    // prayer gets a legible row, since a row that does not fit is a prayer the
    // user cannot see at all.
    val stackRowHeightDp = (
        (size.height.value - 2 * contentPaddingDp - 22) /
            visiblePrayers.size.coerceAtLeast(1)
        ).toInt()
    val stacked = size.height >= 170.dp && stackRowHeightDp >= 24

    WidgetSurface(clickable = true, contentPadding = contentPaddingDp) {
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
        if (!hasPrayerTimes) {
            Text(
                text = visiblePrayers.firstOrNull()?.title.orEmpty()
                    .ifBlank { "Open app to refresh" },
                modifier = GlanceModifier.fillMaxWidth(),
                style = TextStyle(
                    color = bodyTextColor,
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center
                ),
                maxLines = 2
            )
        } else if (stacked) {
            visiblePrayers.forEach { prayer ->
                PrayerTimeRow(prayer, rowHeightDp = stackRowHeightDp.coerceAtMost(34))
            }
        } else {
            val badgeSizeDp = if (columnWidthDp >= 52f) 30 else 25
            val labelFontSize = if (columnWidthDp >= 52f) 11 else 10
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                visiblePrayers.forEachIndexed { index, prayer ->
                    PrayerTimeColumn(
                        prayer,
                        badgeSizeDp = badgeSizeDp,
                        labelFontSize = labelFontSize
                    )
                    if (index != visiblePrayers.lastIndex) {
                        Spacer(GlanceModifier.width(columnSpacingDp.dp))
                    }
                }
            }
        }
        Spacer(GlanceModifier.defaultWeight())
    }
}

@Composable
private fun RowScope.PrayerTimeColumn(
    prayer: DailyPrayerTimeDisplay,
    badgeSizeDp: Int,
    labelFontSize: Int
) {
    Column(
        modifier = GlanceModifier.defaultWeight(),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        PrayerIconBadge(
            prayer.title,
            containerSizeDp = badgeSizeDp,
            iconSizeDp = badgeSizeDp - 11
        )
        Spacer(GlanceModifier.height(4.dp))
        Text(
            text = prayer.title,
            modifier = GlanceModifier.fillMaxWidth(),
            style = TextStyle(
                color = secondaryTextColor,
                fontSize = labelFontSize.sp,
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
                fontSize = labelFontSize.sp,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center
            ),
            maxLines = 1
        )
    }
}

/**
 * The narrow/tall counterpart to [PrayerTimeColumn]: one prayer per line, name
 * left and time right, for widgets too narrow for five columns or tall enough
 * that columns would leave a band of empty card.
 */
@Composable
private fun PrayerTimeRow(prayer: DailyPrayerTimeDisplay, rowHeightDp: Int) {
    Row(
        modifier = GlanceModifier.fillMaxWidth().height(rowHeightDp.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        PrayerIconBadge(
            prayer.title,
            containerSizeDp = rowHeightDp - 6,
            iconSizeDp = rowHeightDp - 17
        )
        Spacer(GlanceModifier.width(8.dp))
        Text(
            text = prayer.title,
            modifier = GlanceModifier.defaultWeight(),
            style = TextStyle(
                color = secondaryTextColor,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold
            ),
            maxLines = 1
        )
        Spacer(GlanceModifier.width(6.dp))
        Text(
            text = prayer.time,
            style = TextStyle(
                color = bodyTextColor,
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold
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
    val cardModifier = GlanceModifier
        .fillMaxSize()
        .background(ImageProvider(R.drawable.widget_surface))
        .let {
            if (clickable) {
                it.clickable(actionStartActivity(context.openWidgetIntent(clickUrl)))
            } else {
                it
            }
        }
        .padding(contentPadding.dp)

    // API 31+ hosts inset widgets themselves; older ones hand over the whole
    // cell, where a card drawn edge to edge reads as a full-bleed block with its
    // rounded corners buried under the neighbouring icons. Hence the margin
    // below API 31 (see res/values(-v31)/dimens.xml), which is what made these
    // look mis-shapen next to the iOS widgets.
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            // appWidgetBackground() belongs on the root view: it is the id the
            // host looks for to clip the widget and to theme its background.
            .appWidgetBackground()
            .padding(widgetOuterMargin())
    ) {
        Column(
            modifier = cardModifier,
            verticalAlignment = Alignment.Top,
            horizontalAlignment = Alignment.Start,
            content = content
        )
    }
}

@Composable
private fun widgetOuterMargin(): Dp {
    val resources = LocalContext.current.resources
    return (
        resources.getDimension(R.dimen.widget_outer_margin) /
            resources.displayMetrics.density
        ).dp
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
        .take(MAX_DAILY_PRAYER_TIMES)
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
