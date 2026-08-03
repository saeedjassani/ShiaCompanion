package com.developer110.shiacompanion.wear

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * The state the watch screen renders from. Covers what the phone can put the watch in —
 * never synced, synced without a location, synced with prayer times — and the roll-over
 * that happens on the watch's own clock.
 */
class PrayerUiStateTest {

    @Test
    fun `waits for the phone until the first snapshot arrives`() {
        val state = storeWith().uiState(nowMillis = 1_000L)

        assertEquals(SyncStatus.WAITING_FOR_PHONE, state.status)
        assertEquals(emptyList<PrayerEntry>(), state.prayers)
        assertNull(state.lastSyncedAtMillis)
    }

    @Test
    fun `asks for a location when the phone has none`() {
        val state = storeWith(
            WearDataKeys.PRAYER_LOCATION to "Location needed",
            WearDataKeys.PRAYER_SCHEDULE to "",
            WearDataKeys.DAILY_PRAYER_NAMES[0] to "Set location",
            WearDataKeys.DAILY_PRAYER_TIMES[0] to "Open app",
            WearDataKeys.UPDATED_AT to 900L,
        ).uiState(nowMillis = 1_000L)

        assertEquals(SyncStatus.NEEDS_LOCATION, state.status)
        // The phone's placeholder rows must never be rendered as prayer times.
        assertEquals(emptyList<PrayerEntry>(), state.prayers)
        assertEquals(900L, state.lastSyncedAtMillis)
    }

    @Test
    fun `shows the next prayer and today's times once synced`() {
        val state = loadedStore().uiState(nowMillis = 1_500L)

        assertEquals(SyncStatus.LOADED, state.status)
        assertEquals("Karbala", state.location)
        assertEquals("Zuhr", state.nextPrayer?.name)
        assertEquals("12:15 pm", state.nextPrayer?.time)
        assertEquals(listOf("Fajr", "Zuhr", "Maghrib"), state.prayers.map { it.name })
    }

    @Test
    fun `rolls over to the following prayer as one passes`() {
        val store = loadedStore()

        assertEquals("Fajr", store.uiState(nowMillis = 500L).nextPrayer?.name)
        assertEquals("Zuhr", store.uiState(nowMillis = 1_500L).nextPrayer?.name)
        assertEquals("Maghrib", store.uiState(nowMillis = 2_500L).nextPrayer?.name)
    }

    @Test
    fun `runs out of banner rather than showing a stale prayer`() {
        val state = loadedStore().uiState(nowMillis = 9_999L)

        assertEquals(SyncStatus.LOADED, state.status)
        assertNull(state.nextPrayer)
    }

    private fun storeWith(vararg payload: Pair<String, Any?>): PrayerDataStore {
        val store = PrayerDataStore.forPreferences(FakePreferences())
        if (payload.isNotEmpty()) store.apply(payload.toMap())
        return store
    }

    private fun loadedStore(): PrayerDataStore = storeWith(
        WearDataKeys.PRAYER_LOCATION to "Karbala",
        WearDataKeys.PRAYER_SCHEDULE to
            "1000|Fajr|4:30 am|Today|Sunrise|5:55 am;" +
            "2000|Zuhr|12:15 pm|Today|Sunset|6:02 pm;" +
            "3000|Maghrib|7:30 pm|Today|Midnight|11:50 pm",
        WearDataKeys.DAILY_PRAYER_NAMES[0] to "Fajr",
        WearDataKeys.DAILY_PRAYER_TIMES[0] to "4:30 am",
        WearDataKeys.DAILY_PRAYER_NAMES[1] to "Zuhr",
        WearDataKeys.DAILY_PRAYER_TIMES[1] to "12:15 pm",
        WearDataKeys.DAILY_PRAYER_NAMES[2] to "Maghrib",
        WearDataKeys.DAILY_PRAYER_TIMES[2] to "7:30 pm",
        WearDataKeys.UPDATED_AT to 500L,
    )
}
