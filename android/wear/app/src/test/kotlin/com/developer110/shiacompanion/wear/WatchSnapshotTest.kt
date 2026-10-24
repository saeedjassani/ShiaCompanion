package com.developer110.shiacompanion.wear

import com.developer110.shiacompanion.wear.data.WatchSnapshot
import com.developer110.shiacompanion.wear.data.parseHijriDays
import com.developer110.shiacompanion.wear.data.parseIslamicEvents
import com.developer110.shiacompanion.wear.data.parsePrayerSchedule
import com.developer110.shiacompanion.wear.data.selectedPrayerCount
import java.time.Instant
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WatchSnapshotTest {
    @Test
    fun `schedule records parse with and without the offer-before pair`() {
        val parsed = parsePrayerSchedule("2000|Zuhr|12:00|Today|Asr|3:00;1000|Fajr|5:00|Today")
        assertEquals(listOf("Fajr", "Zuhr"), parsed.map { it.name })
        assertEquals("", parsed[0].secondaryName)
        assertEquals("Asr", parsed[1].secondaryName)
        assertEquals("3:00", parsed[1].secondaryTime)
    }

    @Test
    fun `malformed schedule records are skipped, not fatal`() {
        val parsed = parsePrayerSchedule("x|Fajr|5:00|Today;1000|Zuhr|12:00;;3000|Asr|3:00|Today")
        assertEquals(listOf("Asr"), parsed.map { it.name })
    }

    @Test
    fun `calendar json parses and drops entries without a start or day`() {
        val days = parseHijriDays("""[{"start":2,"day":14,"month":"M","monthShort":"m","year":1448},
            {"day":3},{"start":1,"day":13,"month":"M","monthShort":"m","year":1448,"event":"E"}]""")
        assertEquals(listOf(13, 14), days.map { it.day })
        assertEquals("E", days[0].eventShort)
        assertEquals(-1, days[0].color)
        val events = parseIslamicEvents("""[{"start":5,"title":"T"},{"start":6,"title":""},{"title":"N"}]""")
        assertEquals(1, events.size)
        assertEquals("T", events[0].short)
        assertTrue(parseHijriDays("not json").isEmpty())
    }

    @Test
    fun `selected prayer count comes from the daily schedule and is bounded`() {
        assertEquals(3, selectedPrayerCount("""[{"items":[{},{},{}]}]"""))
        assertEquals(5, selectedPrayerCount("""[{"items":[{},{}]}]"""))
        assertEquals(5, selectedPrayerCount(""))
    }

    @Test
    fun `next prayer and upcoming window roll into tomorrow`() {
        val snapshot = SampleSnapshot.snapshot()
        assertEquals("Asr", snapshot.nextPrayer(SampleSnapshot.now)?.name)
        val upcoming = snapshot.upcomingPrayers(SampleSnapshot.now)
        assertEquals(listOf("Asr", "Maghrib", "Isha", "Fajr", "Zuhr"), upcoming.map { it.name })
        assertEquals("Tomorrow", upcoming[3].dateLabel)
    }

    @Test
    fun `hijri day is today only within 25 hours of its start`() {
        val snapshot = SampleSnapshot.snapshot()
        assertEquals(13, snapshot.hijriDay(SampleSnapshot.now)?.day)
        val afterTheRun = SampleSnapshot.at(SampleSnapshot.today.plusDays(31), "12:00")
        assertNull(snapshot.hijriDay(afterTheRun))
    }

    @Test
    fun `upcoming events skip today's when the hijri day carries it`() {
        val snapshot = SampleSnapshot.snapshot()
        val events = snapshot.upcomingEvents(SampleSnapshot.now, SampleSnapshot.zone, limit = 2)
        assertEquals(2, events.size)
        assertEquals("Martyrdom", events[0].kind)
    }

    @Test
    fun `sync state distinguishes never synced from no location`() {
        assertFalse(WatchSnapshot.EMPTY.hasSyncedData)
        assertTrue(SampleSnapshot.noLocation.hasSyncedData)
        assertFalse(SampleSnapshot.noLocation.hasPrayerTimes)
    }

    @Test
    fun `transitions are the coming prayers and day starts, in order`() {
        val transitions = SampleSnapshot.snapshot().transitionsAfter(SampleSnapshot.now)
        assertEquals(SampleSnapshot.at(SampleSnapshot.today, "14:58"), transitions.first())
        assertEquals(transitions.sorted(), transitions)
        assertTrue(transitions.all { it.isAfter(SampleSnapshot.now) })
        assertEquals(transitions.size, transitions.toSet().size)
        assertTrue(transitions.contains(SampleSnapshot.at(SampleSnapshot.today.plusDays(1), "00:00")))
        assertFalse(transitions.contains(Instant.EPOCH))
    }
}
