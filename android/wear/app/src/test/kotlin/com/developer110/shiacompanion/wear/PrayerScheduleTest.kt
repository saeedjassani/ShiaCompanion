package com.developer110.shiacompanion.wear

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PrayerScheduleTest {

    @Test
    fun `parses six field records`() {
        val schedule = parsePrayerSchedule(
            "1700000000000|Fajr|4:30 am|Today|Sunrise|5:55 am;" +
                "1700020000000|Zuhr|12:15 pm|Today|Sunset|6:02 pm"
        )

        assertEquals(2, schedule.size)
        assertEquals("Fajr", schedule[0].name)
        assertEquals("4:30 am", schedule[0].time)
        assertEquals("Today", schedule[0].dateLabel)
        assertEquals("Sunrise", schedule[0].secondaryName)
        assertEquals("5:55 am", schedule[0].secondaryTime)
    }

    @Test
    fun `parses four field records without secondary times`() {
        val schedule = parsePrayerSchedule("1700000000000|Maghrib|7:30 pm|Tomorrow")

        assertEquals(1, schedule.size)
        assertEquals("", schedule[0].secondaryName)
        assertEquals("", schedule[0].secondaryTime)
    }

    @Test
    fun `sorts by time and drops malformed records`() {
        val schedule = parsePrayerSchedule(
            "1700020000000|Zuhr|12:15 pm|Today;" +
                "nonsense;" +
                "|missing|epoch|label;" +
                "1700000000000|Fajr|4:30 am|Today"
        )

        assertEquals(listOf("Fajr", "Zuhr"), schedule.map { it.name })
    }

    @Test
    fun `ignores an empty schedule`() {
        assertTrue(parsePrayerSchedule("").isEmpty())
        assertTrue(parsePrayerSchedule("   ").isEmpty())
    }

    @Test
    fun `next prayer is the first one still ahead`() {
        val schedule = parsePrayerSchedule(
            "1000|Fajr|4:30 am|Today;2000|Zuhr|12:15 pm|Today;3000|Maghrib|7:30 pm|Today"
        )

        assertEquals("Zuhr", schedule.firstOrNull { it.epochMillis > 1500L }?.name)
        assertNull(schedule.firstOrNull { it.epochMillis > 3000L })
    }

    @Test
    fun `remaining time is rendered in the largest two units`() {
        val now = 0L
        assertEquals("40m", remainingTime(40 * 60_000L, now))
        assertEquals("2h 5m", remainingTime((2 * 60 + 5) * 60_000L, now))
        assertEquals("3h", remainingTime(3 * 60 * 60_000L, now))
        assertEquals("1d 2h", remainingTime((26 * 60) * 60_000L, now))
        assertEquals("2d", remainingTime((48 * 60) * 60_000L, now))
    }

    @Test
    fun `remaining time is empty once the prayer has passed`() {
        assertEquals("", remainingTime(1_000L, 1_000L))
        assertEquals("", remainingTime(1_000L, 2_000L))
    }

    @Test
    fun `compact time drops the meridiem`() {
        assertEquals("7:30", compactTime("7:30 pm"))
        assertEquals("19:30", compactTime(" 19:30 "))
    }
}
