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
import com.developer110.shiacompanion.wear.data.HijriDay
import com.developer110.shiacompanion.wear.data.SnapshotRepository
import com.developer110.shiacompanion.wear.ui.Routes
import java.time.Instant

/**
 * Today's hijri date: the day over the short month, or the whole date with
 * the day's event as its title. One timeline entry per day the phone sent,
 * so the date turns over at midnight with the app closed.
 */
class HijriDateComplicationService : SuspendingTimelineComplicationDataSourceService() {
    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationDataTimeline? {
        val snapshot = SnapshotRepository.get(this).current
        val now = Instant.now()
        val today = snapshot.hijriDay(now)
        val default = today?.let { data(this, request.complicationType, it) } ?: NoDataComplicationData()
        val days = snapshot.calendarDays.filter { it.start.isAfter(now) }
        val timeline = days.mapIndexedNotNull { index, day ->
            val end = days.getOrNull(index + 1)?.start ?: day.start.plusSeconds(24 * 3600)
            data(this, request.complicationType, day)?.let { TimelineEntry(TimeInterval(day.start, end), it) }
        }
        return ComplicationDataTimeline(default, timeline)
    }

    /** Today's real date once the phone has synced; a sample in the picker before that. */
    override fun getPreviewData(type: ComplicationType): ComplicationData? {
        val day = SnapshotRepository.get(this).current.hijriDay(Instant.now())
            ?: HijriDay(Instant.EPOCH, 13, "Rajab", "Raj", 1448, "", "", "", -1)
        return data(this, type, day, preview = true)
    }

    private fun data(context: Context, type: ComplicationType, day: HijriDay, preview: Boolean = false): ComplicationData? {
        val description = plain(day.shortDateLine)
        val tap = if (preview) null else openRoute(context, Routes.CALENDAR)
        return when (type) {
            ComplicationType.SHORT_TEXT ->
                ShortTextComplicationData.Builder(plain(day.day.toString()), description)
                    .setTitle(plain(day.monthShort))
                    .setTapAction(tap)
                    .build()
            ComplicationType.LONG_TEXT ->
                LongTextComplicationData.Builder(plain("${day.dateLine} ${day.year}"), description)
                    .setTitle(plain(day.eventShort.ifEmpty { context.getString(R.string.islamic_calendar) }))
                    .setMonochromaticImage(monochrome(context, R.drawable.ic_calendar))
                    .setTapAction(tap)
                    .build()
            else -> null
        }
    }
}
