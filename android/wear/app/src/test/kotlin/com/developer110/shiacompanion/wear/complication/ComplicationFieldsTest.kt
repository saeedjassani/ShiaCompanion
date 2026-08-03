package com.developer110.shiacompanion.wear.complication

import com.developer110.shiacompanion.wear.PrayerScheduleEntry
import org.junit.Assert.assertEquals
import org.junit.Test

class ComplicationFieldsTest {

    @Test
    fun `short slots drop the meridiem to fit`() {
        val fields = complicationFields(entry(name = "Maghrib", time = "7:30 pm"))

        assertEquals("7:30", fields.shortText)
        assertEquals("Maghrib", fields.shortTitle)
    }

    @Test
    fun `long slots keep the full time`() {
        val fields = complicationFields(entry(name = "Fajr", time = "4:30 am"))

        assertEquals("Fajr · 4:30 am", fields.longText)
    }

    @Test
    fun `a 24 hour time survives unchanged`() {
        assertEquals("19:30", complicationFields(entry("Maghrib", "19:30")).shortText)
    }

    private fun entry(name: String, time: String) = PrayerScheduleEntry(
        epochMillis = 1_000L,
        name = name,
        time = time,
        dateLabel = "Today",
        secondaryName = "",
        secondaryTime = "",
    )
}
