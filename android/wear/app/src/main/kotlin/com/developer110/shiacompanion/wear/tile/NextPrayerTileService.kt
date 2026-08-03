package com.developer110.shiacompanion.wear.tile

import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DeviceParametersBuilders.DeviceParameters
import androidx.wear.protolayout.DimensionBuilders.expand
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.protolayout.material.Text
import androidx.wear.protolayout.material.Typography
import androidx.wear.protolayout.material.layouts.PrimaryLayout
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.developer110.shiacompanion.wear.MainActivity
import com.developer110.shiacompanion.wear.PrayerDataStore
import com.developer110.shiacompanion.wear.PrayerScheduleEntry
import com.developer110.shiacompanion.wear.R
import com.developer110.shiacompanion.wear.remainingTime
import com.google.common.util.concurrent.ListenableFuture

private const val RESOURCES_VERSION = "1"

private const val ACCENT_COLOR = 0xFFFFD879.toInt()
private const val PRIMARY_TEXT_COLOR = 0xFFFFF3E7.toInt()
private const val SECONDARY_TEXT_COLOR = 0xFFE4C7B3.toInt()

/**
 * The "Next Prayer" tile — the Wear counterpart of the watchOS complication.
 *
 * Everything is rendered from the last snapshot the phone sent, and the timeline carries
 * one entry per upcoming prayer, each valid until that prayer starts. The tile therefore
 * rolls over on the watch's own clock, with the phone out of range for days if need be.
 */
class NextPrayerTileService : TileService() {

    override fun onTileRequest(
        requestParams: RequestBuilders.TileRequest
    ): ListenableFuture<TileBuilders.Tile> = CallbackToFutureAdapter.getFuture { completer ->
        completer.set(buildTile(requestParams))
        "NextPrayerTileRequest"
    }

    override fun onTileResourcesRequest(
        requestParams: RequestBuilders.ResourcesRequest
    ): ListenableFuture<ResourceBuilders.Resources> =
        CallbackToFutureAdapter.getFuture { completer ->
            completer.set(
                ResourceBuilders.Resources.Builder()
                    .setVersion(RESOURCES_VERSION)
                    .build()
            )
            "NextPrayerTileResources"
        }

    private fun buildTile(requestParams: RequestBuilders.TileRequest): TileBuilders.Tile {
        val deviceParameters = requestParams.deviceConfiguration
        val store = PrayerDataStore.get(this)
        val now = System.currentTimeMillis()
        val upcoming = store.upcomingPrayers(now)
        val location = store.location

        val timeline = TimelineBuilders.Timeline.Builder()
        for (window in tileWindows(upcoming, now)) {
            timeline.addTimelineEntry(
                TimelineBuilders.TimelineEntry.Builder()
                    .setValidity(
                        TimelineBuilders.TimeInterval.Builder()
                            .setStartMillis(window.startMillis)
                            .setEndMillis(window.endMillis)
                            .build()
                    )
                    .setLayout(
                        LayoutElementBuilders.Layout.Builder()
                            .setRoot(
                                prayerLayout(
                                    deviceParameters,
                                    window.prayer,
                                    location,
                                    window.startMillis,
                                )
                            )
                            .build()
                    )
                    .build()
            )
        }

        // An entry without validity is the fallback the renderer falls back to once every
        // other entry has expired — which is also the "nothing synced yet" case.
        timeline.addTimelineEntry(
            TimelineBuilders.TimelineEntry.Builder()
                .setLayout(
                    LayoutElementBuilders.Layout.Builder()
                        .setRoot(emptyLayout(deviceParameters, store.hasSyncedData))
                        .build()
                )
                .build()
        )

        return TileBuilders.Tile.Builder()
            .setResourcesVersion(RESOURCES_VERSION)
            .setTileTimeline(timeline.build())
            // Backstop: the phone pushes updates and each prayer refreshes the tile, so
            // this only matters if both are missed.
            .setFreshnessIntervalMillis(60 * 60 * 1000L)
            .build()
    }

    private fun prayerLayout(
        deviceParameters: DeviceParameters,
        prayer: PrayerScheduleEntry,
        location: String,
        renderedAt: Long,
    ): LayoutElementBuilders.LayoutElement {
        val heading = if (prayer.dateLabel.isBlank() || prayer.dateLabel == "Today") {
            getString(R.string.next_prayer)
        } else {
            getString(R.string.next_prayer_on, prayer.dateLabel)
        }
        val remaining = remainingTime(prayer.epochMillis, renderedAt)
        val footer = when {
            remaining.isNotEmpty() -> getString(R.string.in_time, remaining)
            location.isNotEmpty() -> location
            else -> ""
        }

        val content = LayoutElementBuilders.Column.Builder()
            .setWidth(expand())
            .addContent(
                Text.Builder(this, prayer.name)
                    .setTypography(Typography.TYPOGRAPHY_TITLE3)
                    .setColor(argb(ACCENT_COLOR))
                    .setMaxLines(1)
                    .build()
            )
            .addContent(
                Text.Builder(this, prayer.time)
                    .setTypography(Typography.TYPOGRAPHY_DISPLAY2)
                    .setColor(argb(PRIMARY_TEXT_COLOR))
                    .setMaxLines(1)
                    .build()
            )
            .build()

        return clickable(
            PrimaryLayout.Builder(deviceParameters)
                .setResponsiveContentInsetEnabled(true)
                .setPrimaryLabelTextContent(
                    Text.Builder(this, heading)
                        .setTypography(Typography.TYPOGRAPHY_CAPTION1)
                        .setColor(argb(SECONDARY_TEXT_COLOR))
                        .setMaxLines(1)
                        .build()
                )
                .setContent(content)
                .apply {
                    if (footer.isNotEmpty()) {
                        setSecondaryLabelTextContent(
                            Text.Builder(this@NextPrayerTileService, footer)
                                .setTypography(Typography.TYPOGRAPHY_CAPTION2)
                                .setColor(argb(SECONDARY_TEXT_COLOR))
                                .setMaxLines(1)
                                .build()
                        )
                    }
                }
                .build()
        )
    }

    private fun emptyLayout(
        deviceParameters: DeviceParameters,
        hasSyncedData: Boolean,
    ): LayoutElementBuilders.LayoutElement {
        val hint = if (hasSyncedData) {
            getString(R.string.needs_location_message)
        } else {
            getString(R.string.waiting_for_phone_message)
        }

        return clickable(
            PrimaryLayout.Builder(deviceParameters)
                .setResponsiveContentInsetEnabled(true)
                .setPrimaryLabelTextContent(
                    Text.Builder(this, getString(R.string.app_name))
                        .setTypography(Typography.TYPOGRAPHY_CAPTION1)
                        .setColor(argb(SECONDARY_TEXT_COLOR))
                        .setMaxLines(1)
                        .build()
                )
                .setContent(
                    Text.Builder(this, hint)
                        .setTypography(Typography.TYPOGRAPHY_BODY2)
                        .setColor(argb(PRIMARY_TEXT_COLOR))
                        .setMaxLines(3)
                        .build()
                )
                .build()
        )
    }

    /** Wraps [content] so tapping anywhere on the tile opens the watch app. */
    private fun clickable(
        content: LayoutElementBuilders.LayoutElement
    ): LayoutElementBuilders.LayoutElement =
        LayoutElementBuilders.Box.Builder()
            .setWidth(expand())
            .setHeight(expand())
            .setModifiers(
                ModifiersBuilders.Modifiers.Builder()
                    .setClickable(
                        ModifiersBuilders.Clickable.Builder()
                            .setId("open_app")
                            .setOnClick(
                                ActionBuilders.LaunchAction.Builder()
                                    .setAndroidActivity(
                                        ActionBuilders.AndroidActivity.Builder()
                                            .setPackageName(packageName)
                                            .setClassName(MainActivity::class.java.name)
                                            .build()
                                    )
                                    .build()
                            )
                            .build()
                    )
                    .build()
            )
            .addContent(content)
            .build()
}
