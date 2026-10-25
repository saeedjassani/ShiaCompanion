package com.developer110.shiacompanion.wear.tile

import android.content.ComponentName
import android.content.Context
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.DimensionBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.LayoutElementBuilders.LayoutElement
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.layout.column
import androidx.wear.protolayout.layout.spacer
import androidx.wear.protolayout.material3.MaterialScope
import androidx.wear.protolayout.material3.Typography
import androidx.wear.protolayout.material3.primaryLayout
import androidx.wear.protolayout.material3.text
import androidx.wear.protolayout.material3.textEdgeButton
import androidx.wear.protolayout.modifiers.clickable
import androidx.wear.protolayout.types.argb
import androidx.wear.protolayout.types.layoutString
import androidx.wear.tiles.Material3TileService
import androidx.wear.tiles.RequestBuilders.TileRequest
import androidx.wear.tiles.TileBuilders.Tile
import androidx.wear.tiles.tile
import com.developer110.shiacompanion.wear.MainActivity
import com.developer110.shiacompanion.wear.R
import com.developer110.shiacompanion.wear.data.SnapshotRepository
import com.developer110.shiacompanion.wear.ui.Routes
import java.time.Instant
import java.time.ZoneId
import kotlin.time.Duration.Companion.hours
import androidx.wear.protolayout.material3.ColorScheme as TileColorScheme

/**
 * The prayer times tile: the next prayer large, the two after it beneath,
 * and today's hijri date on the edge button, which opens the calendar.
 */
class PrayerTileService : Material3TileService(
    // The phone's gold and brown, not the watch face's dynamic colours: the
    // tile should read as Shia Companion beside the app.
    allowDynamicTheme = false,
    defaultColorScheme = tileColorScheme,
) {
    override suspend fun MaterialScope.tileResponse(requestParams: TileRequest): Tile {
        val snapshot = SnapshotRepository.get(context).current
        val entries = buildPrayerTileTimeline(snapshot, Instant.now(), ZoneId.systemDefault())
        val timeline = TimelineBuilders.Timeline.Builder()
        entries.forEach { entry ->
            val validity = TimelineBuilders.TimeInterval.Builder()
                .setStartMillis(entry.start.toEpochMilli())
                .apply { entry.end?.let { setEndMillis(it.toEpochMilli()) } }
                .build()
            timeline.addTimelineEntry(
                TimelineBuilders.TimelineEntry.Builder()
                    .setValidity(validity)
                    .setLayout(LayoutElementBuilders.Layout.fromLayoutElement(layout(context, entry)))
                    .build()
            )
        }
        // The timeline already moves on at each prayer; this re-reads the
        // snapshot now and then in case the phone's sync never reached us.
        return tile(timeline = timeline.build(), freshness = 6.hours)
    }

    companion object {
        val tileColorScheme = TileColorScheme(
            primary = 0xFFE4C27A.toInt().argb,
            onPrimary = 0xFF2A1E16.toInt().argb,
            primaryContainer = 0xFF4A3A2E.toInt().argb,
            onPrimaryContainer = 0xFFF2EBE2.toInt().argb,
            surfaceContainer = 0xFF3A2A1F.toInt().argb,
            onSurface = 0xFFF2EBE2.toInt().argb,
            onSurfaceVariant = 0xFFBFB0A2.toInt().argb,
            background = 0xFF000000.toInt().argb,
            onBackground = 0xFFF2EBE2.toInt().argb,
        )

        private fun open(context: Context, route: String, id: String) = clickable(
            action = ActionBuilders.launchAction(
                ComponentName(context, MainActivity::class.java),
                mapOf(MainActivity.EXTRA_ROUTE to ActionBuilders.stringExtra(route)),
            ),
            id = id,
        )

        /** "Up Next", or "Up Next · Tomorrow" once the next time is on another day. */
        private fun title(context: Context, entry: PrayerTileEntry): String {
            val next = entry.next ?: return context.getString(R.string.tile_prayer_label)
            val zone = ZoneId.systemDefault()
            val sameDay = entry.start.atZone(zone).toLocalDate() == next.time.atZone(zone).toLocalDate()
            return if (sameDay) context.getString(R.string.up_next)
            else context.getString(R.string.up_next_on, next.dateLabel)
        }

        internal fun MaterialScope.layout(context: Context, entry: PrayerTileEntry): LayoutElement {
            val next = entry.next
            return primaryLayout(
                onClick = open(context, Routes.HOME, "open_home"),
                titleSlot = { text(title(context, entry).layoutString) },
                mainSlot = {
                    if (next == null) {
                        text(
                            context.getString(R.string.tile_open_phone).layoutString,
                            typography = Typography.BODY_MEDIUM,
                            maxLines = 3,
                        )
                    } else {
                        column(
                            text(
                                next.name.layoutString,
                                typography = Typography.TITLE_MEDIUM,
                                color = colorScheme.primary,
                            ),
                            text(next.displayTime.layoutString, typography = Typography.DISPLAY_SMALL),
                            spacer(height = DimensionBuilders.dp(4f)),
                            *entry.after.map { later ->
                                text(
                                    "${later.name}  ${later.displayTime}".layoutString,
                                    typography = Typography.BODY_SMALL,
                                    color = colorScheme.onSurfaceVariant,
                                )
                            }.toTypedArray(),
                            horizontalAlignment = LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER,
                        )
                    }
                },
                bottomSlot = entry.hijriShort?.let { hijri ->
                    {
                        textEdgeButton(onClick = open(context, Routes.CALENDAR, "open_calendar")) {
                            text(hijri.layoutString)
                        }
                    }
                },
            )
        }
    }
}
