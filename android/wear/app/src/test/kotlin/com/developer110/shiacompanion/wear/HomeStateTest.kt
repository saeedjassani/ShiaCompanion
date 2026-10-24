package com.developer110.shiacompanion.wear

import com.developer110.shiacompanion.wear.data.WatchSnapshot
import com.developer110.shiacompanion.wear.tile.TILE_TIMES_AFTER
import com.developer110.shiacompanion.wear.tile.buildPrayerTileTimeline
import com.developer110.shiacompanion.wear.ui.HomeMode
import com.developer110.shiacompanion.wear.ui.buildHomeState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HomeStateTest {
    private val zone = SampleSnapshot.zone

    @Test
    fun `modes follow what the phone has sent`() {
        assertEquals(HomeMode.WAITING_FOR_PHONE, buildHomeState(WatchSnapshot.EMPTY, SampleSnapshot.now, zone).mode)
        assertEquals(HomeMode.NEEDS_LOCATION, buildHomeState(SampleSnapshot.noLocation, SampleSnapshot.now, zone).mode)
        assertEquals(HomeMode.LOADED, buildHomeState(SampleSnapshot.snapshot(), SampleSnapshot.now, zone).mode)
    }

    @Test
    fun `the banner's prayer is not repeated in the list`() {
        val state = buildHomeState(SampleSnapshot.snapshot(), SampleSnapshot.now, zone)
        assertEquals("Asr", state.next?.name)
        assertEquals(listOf("Maghrib", "Isha", "Fajr", "Zuhr"), state.rows.map { it.entry.name })
    }

    @Test
    fun `the day is named once, where the list crosses into it`() {
        val state = buildHomeState(SampleSnapshot.snapshot(), SampleSnapshot.now, zone)
        assertEquals(listOf(null, null, "Tomorrow", null), state.rows.map { it.dayBreak })
    }

    @Test
    fun `after the last prayer the banner says tomorrow and the list does not repeat it`() {
        val late = SampleSnapshot.at(SampleSnapshot.today, "21:00")
        val state = buildHomeState(SampleSnapshot.snapshot(), late, zone)
        assertEquals("Fajr", state.next?.name)
        assertTrue(state.rows.all { it.dayBreak == null })
    }

    @Test
    fun `the open screen wakes at the next prayer`() {
        val state = buildHomeState(SampleSnapshot.snapshot(), SampleSnapshot.now, zone)
        assertEquals(SampleSnapshot.at(SampleSnapshot.today, "14:58"), state.nextChange)
    }

    @Test
    fun `tile timeline cuts an entry at every prayer`() {
        val entries = buildPrayerTileTimeline(SampleSnapshot.snapshot(), SampleSnapshot.now, zone)
        assertEquals(SampleSnapshot.now, entries[0].start)
        assertEquals(entries[1].start, entries[0].end)
        assertEquals("Asr", entries[0].next?.name)
        assertEquals("Maghrib", entries[1].next?.name)
        assertEquals(TILE_TIMES_AFTER, entries[0].after.size)
        assertEquals("13 Jum I", entries[0].hijriShort)
        assertNull(entries.last().end)
    }

    @Test
    fun `tile without a location is one open-ended placeholder`() {
        val entries = buildPrayerTileTimeline(SampleSnapshot.noLocation, SampleSnapshot.now, zone)
        assertEquals(1, entries.size)
        assertNull(entries[0].next)
    }
}
