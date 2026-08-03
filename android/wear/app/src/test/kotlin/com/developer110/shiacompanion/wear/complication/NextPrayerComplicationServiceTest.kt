package com.developer110.shiacompanion.wear.complication

import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.LongTextComplicationData
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.developer110.shiacompanion.wear.PrayerDataStore
import com.developer110.shiacompanion.wear.WearDataKeys
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * Exercises the real data source: what a watch face gets for each slot it supports, and
 * what it gets before the phone has ever synced.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
class NextPrayerComplicationServiceTest {

    private lateinit var service: NextPrayerComplicationService

    @Before
    fun setUp() {
        service = Robolectric.buildService(NextPrayerComplicationService::class.java)
            .create()
            .get()
        store().clear()
    }

    @After
    fun tearDown() {
        store().clear()
    }

    @Test
    fun `short text carries the time, with the prayer as its title`() {
        seedNextPrayer()

        val data = request(ComplicationType.SHORT_TEXT) as ShortTextComplicationData

        assertEquals("7:30", data.text.getTextAt(resources(), currentInstant()).toString())
        assertNotNull(data.title)
        assertNotNull(data.tapAction)
    }

    @Test
    fun `long text carries the prayer and the time`() {
        seedNextPrayer()

        val data = request(ComplicationType.LONG_TEXT) as LongTextComplicationData

        assertEquals(
            "Maghrib · 7:30 pm",
            data.text.getTextAt(resources(), currentInstant()).toString(),
        )
        // The countdown title is a time difference the watch face ticks down itself.
        assertNotNull(data.title)
    }

    @Test
    fun `falls back to a prompt before the phone has ever synced`() {
        val data = request(ComplicationType.SHORT_TEXT) as ShortTextComplicationData

        assertEquals("--:--", data.text.getTextAt(resources(), currentInstant()).toString())
        assertNotNull(data.tapAction)
    }

    @Test
    fun `declines slots it cannot fill`() {
        seedNextPrayer()

        assertNull(request(ComplicationType.RANGED_VALUE))
    }

    @Test
    fun `previews with sample data so watch faces can render the picker`() {
        assertNotNull(service.getPreviewData(ComplicationType.SHORT_TEXT))
        assertNotNull(service.getPreviewData(ComplicationType.LONG_TEXT))
    }

    private fun request(type: ComplicationType) = runBlocking {
        service.onComplicationRequest(
            androidx.wear.watchface.complications.datasource.ComplicationRequest(
                complicationInstanceId = 1,
                complicationType = type,
            )
        )
    }

    private fun seedNextPrayer() {
        val now = System.currentTimeMillis()
        store().apply(
            mapOf(
                WearDataKeys.PRAYER_LOCATION to "Karbala",
                WearDataKeys.PRAYER_SCHEDULE to
                    "${now + 60 * 60_000L}|Maghrib|7:30 pm|Today|Midnight|11:50 pm",
                WearDataKeys.UPDATED_AT to now,
            )
        )
    }

    private fun store() = PrayerDataStore.get(RuntimeEnvironment.getApplication())

    private fun resources() = RuntimeEnvironment.getApplication().resources

    private fun currentInstant() = java.time.Instant.now()
}
