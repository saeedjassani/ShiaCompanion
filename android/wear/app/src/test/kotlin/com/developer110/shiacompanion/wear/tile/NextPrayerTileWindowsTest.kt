package com.developer110.shiacompanion.wear.tile

import com.developer110.shiacompanion.wear.PrayerScheduleEntry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The tile's timeline is what keeps it correct with the phone out of range, so this covers
 * the slicing directly: contiguous windows, each ending on the prayer it announces.
 */
class NextPrayerTileWindowsTest {

    @Test
    fun `each window ends on the prayer it announces`() {
        val windows = tileWindows(schedule, nowMillis = 0L)

        assertEquals(listOf("Fajr", "Zuhr", "Maghrib"), windows.map { it.prayer.name })
        assertEquals(listOf(1_000L, 2_000L, 3_000L), windows.map { it.endMillis })
    }

    @Test
    fun `windows are contiguous, starting from now`() {
        val windows = tileWindows(schedule, nowMillis = 250L)

        assertEquals(250L, windows.first().startMillis)
        windows.zipWithNext { earlier, later ->
            assertEquals(earlier.endMillis, later.startMillis)
        }
        assertTrue(windows.all { it.startMillis < it.endMillis })
    }

    @Test
    fun `prayers already past are dropped`() {
        val windows = tileWindows(schedule, nowMillis = 1_500L)

        assertEquals(listOf("Zuhr", "Maghrib"), windows.map { it.prayer.name })
        assertEquals(1_500L, windows.first().startMillis)
    }

    @Test
    fun `an exhausted schedule produces no windows, leaving only the fallback entry`() {
        assertTrue(tileWindows(schedule, nowMillis = 9_999L).isEmpty())
        assertTrue(tileWindows(emptyList(), nowMillis = 0L).isEmpty())
    }

    @Test
    fun `the timeline is capped so eight days of prayers cannot bloat the tile`() {
        val long = (1..100).map { entry(it * 1_000L, "Prayer $it") }

        val windows = tileWindows(long, nowMillis = 0L, limit = 12)

        assertEquals(12, windows.size)
        assertEquals("Prayer 1", windows.first().prayer.name)
        assertEquals("Prayer 12", windows.last().prayer.name)
    }

    private val schedule = listOf(
        entry(1_000L, "Fajr"),
        entry(2_000L, "Zuhr"),
        entry(3_000L, "Maghrib"),
    )

    private fun entry(epochMillis: Long, name: String) = PrayerScheduleEntry(
        epochMillis = epochMillis,
        name = name,
        time = "7:30 pm",
        dateLabel = "Today",
        secondaryName = "",
        secondaryTime = "",
    )
}
