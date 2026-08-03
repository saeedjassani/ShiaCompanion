package com.developer110.shiacompanion.wear

import java.util.Calendar
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PrayerDataStoreTest {

    @Test
    fun `reports waiting for the phone until the first payload lands`() {
        val store = PrayerDataStore.forPreferences(FakePreferences())

        assertFalse(store.hasSyncedData)
        assertFalse(store.hasPrayerTimes)
        assertNull(store.lastSyncedAtMillis)
    }

    @Test
    fun `a payload without prayer times counts as synced but not located`() {
        val store = PrayerDataStore.forPreferences(FakePreferences())

        // What the phone publishes before a location has been chosen.
        store.apply(
            mapOf(
                WearDataKeys.PRAYER_LOCATION to "Location needed",
                WearDataKeys.PRAYER_SCHEDULE to "",
                WearDataKeys.DAILY_PRAYER_NAMES[0] to "Set location",
                WearDataKeys.DAILY_PRAYER_TIMES[0] to "Open app",
                WearDataKeys.UPDATED_AT to 1_700_000_000_000L,
            )
        )

        assertTrue(store.hasSyncedData)
        assertFalse(store.hasPrayerTimes)
        assertEquals(1_700_000_000_000L, store.lastSyncedAtMillis)
        assertEquals("Location needed", store.location)
    }

    @Test
    fun `a payload without a timestamp still counts as a sync`() {
        val store = PrayerDataStore.forPreferences(FakePreferences())

        store.apply(mapOf(WearDataKeys.PRAYER_LOCATION to "Karbala"))

        assertTrue(store.hasSyncedData)
    }

    @Test
    fun `unknown keys are ignored`() {
        val prefs = FakePreferences()
        val store = PrayerDataStore.forPreferences(prefs)

        store.apply(mapOf("sc_something_else" to "value"))

        assertFalse(store.hasSyncedData)
        assertNull(prefs.getString("sc_something_else", null))
    }

    @Test
    fun `next prayer comes off the synced schedule`() {
        val store = PrayerDataStore.forPreferences(FakePreferences())
        store.apply(
            mapOf(
                WearDataKeys.PRAYER_SCHEDULE to
                    "1000|Fajr|4:30 am|Today|Sunrise|5:55 am;" +
                    "3000|Zuhr|12:15 pm|Today|Sunset|6:02 pm",
                WearDataKeys.UPDATED_AT to 500L,
            )
        )

        assertTrue(store.hasPrayerTimes)
        assertEquals("Zuhr", store.nextPrayer(afterMillis = 2_000L)?.name)
        assertEquals("Sunset", store.nextPrayer(afterMillis = 2_000L)?.secondaryName)
        assertEquals(listOf("Zuhr"), store.upcomingPrayers(2_000L).map { it.name })
        assertNull(store.nextPrayer(afterMillis = 4_000L))
    }

    @Test
    fun `daily prayers roll over to the next day on their own`() {
        val store = PrayerDataStore.forPreferences(FakePreferences())
        val today = startOfDay(System.currentTimeMillis())
        val tomorrow = today + DAY_MILLIS

        store.apply(
            mapOf(
                WearDataKeys.DAILY_PRAYER_SCHEDULE to
                    """
                    [
                      {"start": $today, "items": [
                        {"title": "Fajr", "time": "4:30 am", "url": ""},
                        {"title": "Zuhr", "time": "12:15 pm", "url": ""}
                      ]},
                      {"start": $tomorrow, "items": [
                        {"title": "Fajr", "time": "4:31 am", "url": ""},
                        {"title": "Zuhr", "time": "12:16 pm", "url": ""}
                      ]}
                    ]
                    """.trimIndent(),
                WearDataKeys.UPDATED_AT to today,
            )
        )

        assertEquals(
            listOf(PrayerEntry("Fajr", "4:30 am"), PrayerEntry("Zuhr", "12:15 pm")),
            store.dailyPrayers(today + 8 * 60 * 60 * 1000L),
        )
        assertEquals(
            listOf(PrayerEntry("Fajr", "4:31 am"), PrayerEntry("Zuhr", "12:16 pm")),
            store.dailyPrayers(tomorrow + 8 * 60 * 60 * 1000L),
        )
    }

    @Test
    fun `daily prayers fall back to the flat keys`() {
        val store = PrayerDataStore.forPreferences(FakePreferences())
        store.apply(
            mapOf(
                WearDataKeys.DAILY_PRAYER_NAMES[0] to "Fajr",
                WearDataKeys.DAILY_PRAYER_TIMES[0] to "4:30 am",
                WearDataKeys.DAILY_PRAYER_NAMES[1] to "Zuhr",
                WearDataKeys.DAILY_PRAYER_TIMES[1] to "12:15 pm",
                WearDataKeys.UPDATED_AT to 1L,
            )
        )

        assertEquals(
            listOf(PrayerEntry("Fajr", "4:30 am"), PrayerEntry("Zuhr", "12:15 pm")),
            store.dailyPrayers(),
        )
    }

    @Test
    fun `a day the schedule does not cover falls back rather than showing nothing`() {
        val store = PrayerDataStore.forPreferences(FakePreferences())
        val today = startOfDay(System.currentTimeMillis())

        store.apply(
            mapOf(
                WearDataKeys.DAILY_PRAYER_SCHEDULE to
                    """[{"start": $today, "items": [{"title": "Fajr", "time": "4:30 am"}]}]""",
                WearDataKeys.DAILY_PRAYER_NAMES[0] to "Fajr",
                WearDataKeys.DAILY_PRAYER_TIMES[0] to "4:29 am",
                WearDataKeys.UPDATED_AT to today,
            )
        )

        assertEquals(
            listOf(PrayerEntry("Fajr", "4:29 am")),
            store.dailyPrayers(today + 30 * DAY_MILLIS),
        )
    }

    @Test
    fun `malformed schedule json does not crash the watch`() {
        val store = PrayerDataStore.forPreferences(FakePreferences())
        store.apply(
            mapOf(
                WearDataKeys.DAILY_PRAYER_SCHEDULE to "{not json",
                WearDataKeys.UPDATED_AT to 1L,
            )
        )

        assertEquals(emptyList<PrayerEntry>(), store.dailyPrayers())
    }

    private companion object {
        const val DAY_MILLIS = 24 * 60 * 60 * 1000L

        fun startOfDay(millis: Long): Long = Calendar.getInstance().apply {
            timeInMillis = millis
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
    }
}
