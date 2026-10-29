package com.developer110.shiacompanion.wear.complication

import android.content.Context
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.LongTextComplicationData
import androidx.wear.watchface.complications.data.NoDataComplicationData
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.datasource.ComplicationDataTimeline
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingTimelineComplicationDataSourceService
import androidx.wear.watchface.complications.datasource.TimeInterval
import androidx.wear.watchface.complications.datasource.TimelineEntry
import com.developer110.shiacompanion.wear.R
import com.developer110.shiacompanion.wear.data.PrayerScheduleEntry
import com.developer110.shiacompanion.wear.data.SnapshotRepository
import com.developer110.shiacompanion.wear.tile.buildPrayerTileTimeline
import com.developer110.shiacompanion.wear.ui.Routes
import com.developer110.shiacompanion.wear.ui.prayerIconRes
import java.time.Instant
import java.time.ZoneId

/**
 * The next prayer on the watch face: its time, with its name as the title.
 * Sent as a timeline, one entry per stretch between prayers, so the face
 * moves on to the next prayer by itself.
 */
class NextPrayerComplicationService : SuspendingTimelineComplicationDataSourceService() {
    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationDataTimeline? {
        val snapshot = SnapshotRepository.get(this).current
        val entries = buildPrayerTileTimeline(snapshot, Instant.now(), ZoneId.systemDefault())
        val first = entries.first()
        val default = first.next?.let { data(this, request.complicationType, it) }
            ?: NoDataComplicationData()
        val timeline = entries.drop(1).mapNotNull { entry ->
            val next = entry.next ?: return@mapNotNull null
            val end = entry.end ?: entry.start.plusSeconds(24 * 3600)
            val data = data(this, request.complicationType, next) ?: return@mapNotNull null
            TimelineEntry(TimeInterval(entry.start, end), data)
        }
        return ComplicationDataTimeline(default, timeline)
    }

    /** The real next prayer once the phone has synced; a sample in the picker before that. */
    override fun getPreviewData(type: ComplicationType): ComplicationData? {
        val entry = SnapshotRepository.get(this).current.nextPrayer(Instant.now())
            ?: PrayerScheduleEntry(Instant.EPOCH, "Maghrib", "6:42", "")
        return data(this, type, entry, preview = true)
    }

    private fun data(
        context: Context,
        type: ComplicationType,
        entry: PrayerScheduleEntry,
        preview: Boolean = false,
    ): ComplicationData? {
        val description = plain("${entry.name} ${entry.displayTime}")
        val tap = if (preview) null else openRoute(context, Routes.HOME)
        return when (type) {
            ComplicationType.SHORT_TEXT ->
                ShortTextComplicationData.Builder(plain(entry.displayTime), description)
                    .setTitle(plain(entry.name))
                    .setMonochromaticImage(monochrome(context, prayerIconRes(entry.name)))
                    .setTapAction(tap)
                    .build()
            ComplicationType.LONG_TEXT ->
                LongTextComplicationData.Builder(plain("${entry.name} ${entry.displayTime}"), description)
                    .setTitle(plain(context.getString(R.string.complication_next_prayer)))
                    .setMonochromaticImage(monochrome(context, prayerIconRes(entry.name)))
                    .setTapAction(tap)
                    .build()
            else -> null
        }
    }
}
