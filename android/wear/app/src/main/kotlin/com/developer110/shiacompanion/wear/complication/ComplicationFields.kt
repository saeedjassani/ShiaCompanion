package com.developer110.shiacompanion.wear.complication

import com.developer110.shiacompanion.wear.PrayerScheduleEntry
import com.developer110.shiacompanion.wear.compactTime

/** The text each complication slot shows for a prayer. Separated out so it can be tested. */
internal data class ComplicationFields(
    /** Tight slots: the time without its meridiem. */
    val shortText: String,
    val shortTitle: String,
    val longText: String,
)

internal fun complicationFields(prayer: PrayerScheduleEntry) = ComplicationFields(
    shortText = compactTime(prayer.time),
    shortTitle = prayer.name,
    longText = "${prayer.name} · ${prayer.time}",
)
