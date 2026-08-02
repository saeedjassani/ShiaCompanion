package com.developer110.shiacompanion.wear.complication

import android.app.PendingIntent
import android.content.Intent
import android.graphics.drawable.Icon
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationText
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.CountDownTimeReference
import androidx.wear.watchface.complications.data.LongTextComplicationData
import androidx.wear.watchface.complications.data.MonochromaticImage
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.data.TimeDifferenceComplicationText
import androidx.wear.watchface.complications.data.TimeDifferenceStyle
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService
import com.developer110.shiacompanion.wear.MainActivity
import com.developer110.shiacompanion.wear.PrayerDataStore
import com.developer110.shiacompanion.wear.PrayerScheduleEntry
import com.developer110.shiacompanion.wear.R
import com.developer110.shiacompanion.wear.compactTime
import com.developer110.shiacompanion.wear.prayerIconRes
import java.time.Instant
import java.util.concurrent.TimeUnit

/**
 * Watch face complication showing the next prayer, from the last snapshot the phone sent.
 *
 * The countdown is a [TimeDifferenceComplicationText], so the watch face ticks it down
 * itself; the text only has to be rebuilt when the prayer rolls over, which
 * `PrayerSurfaces` schedules an alarm for.
 */
class NextPrayerComplicationService : SuspendingComplicationDataSourceService() {

    override fun getPreviewData(type: ComplicationType): ComplicationData? {
        val preview = PrayerScheduleEntry(
            epochMillis = System.currentTimeMillis() + 60 * 60 * 1000L,
            name = "Maghrib",
            time = "7:30 pm",
            dateLabel = "Today",
            secondaryName = "",
            secondaryTime = "",
        )
        return complicationData(type, preview)
    }

    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData? {
        val store = PrayerDataStore.get(this)
        val next = store.nextPrayer()
            ?: return emptyComplicationData(request.complicationType, store.hasSyncedData)

        return complicationData(request.complicationType, next)
    }

    private fun complicationData(
        type: ComplicationType,
        prayer: PrayerScheduleEntry,
    ): ComplicationData? {
        val description = PlainComplicationText
            .Builder(getString(R.string.complication_description, prayer.name, prayer.time))
            .build()
        val countdown = TimeDifferenceComplicationText
            .Builder(
                TimeDifferenceStyle.SHORT_DUAL_UNIT,
                CountDownTimeReference(Instant.ofEpochMilli(prayer.epochMillis)),
            )
            .setMinimumTimeUnit(TimeUnit.MINUTES)
            .build()

        return when (type) {
            ComplicationType.SHORT_TEXT -> ShortTextComplicationData.Builder(
                text = PlainComplicationText.Builder(compactTime(prayer.time)).build(),
                contentDescription = description,
            )
                .setTitle(PlainComplicationText.Builder(prayer.name).build())
                .setMonochromaticImage(monochromaticImage(prayer.name))
                .setTapAction(openAppIntent())
                .build()

            ComplicationType.LONG_TEXT -> LongTextComplicationData.Builder(
                text = PlainComplicationText
                    .Builder("${prayer.name} · ${prayer.time}")
                    .build(),
                contentDescription = description,
            )
                .setTitle(countdown)
                .setMonochromaticImage(monochromaticImage(prayer.name))
                .setTapAction(openAppIntent())
                .build()

            else -> null
        }
    }

    private fun emptyComplicationData(
        type: ComplicationType,
        hasSyncedData: Boolean,
    ): ComplicationData? {
        val hint = if (hasSyncedData) {
            getString(R.string.needs_location_title)
        } else {
            getString(R.string.waiting_for_phone_title)
        }
        val description: ComplicationText = PlainComplicationText.Builder(hint).build()

        return when (type) {
            ComplicationType.SHORT_TEXT -> ShortTextComplicationData.Builder(
                text = PlainComplicationText.Builder("--:--").build(),
                contentDescription = description,
            )
                .setTapAction(openAppIntent())
                .build()

            ComplicationType.LONG_TEXT -> LongTextComplicationData.Builder(
                text = PlainComplicationText.Builder(hint).build(),
                contentDescription = description,
            )
                .setTapAction(openAppIntent())
                .build()

            else -> null
        }
    }

    private fun monochromaticImage(prayerName: String): MonochromaticImage =
        MonochromaticImage.Builder(Icon.createWithResource(this, prayerIconRes(prayerName)))
            .build()

    private fun openAppIntent(): PendingIntent = PendingIntent.getActivity(
        this,
        0,
        Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}
