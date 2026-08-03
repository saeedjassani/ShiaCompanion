package com.developer110.shiacompanion.wear.tile

import androidx.wear.protolayout.DeviceParametersBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.developer110.shiacompanion.wear.PrayerDataStore
import com.developer110.shiacompanion.wear.WearDataKeys
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * Builds the real tile from the real service, so a layout the renderer would reject — a
 * missing resources version, an empty timeline, a builder that throws — fails here.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
class NextPrayerTileServiceTest {

    private lateinit var service: NextPrayerTileService

    @Before
    fun setUp() {
        service = Robolectric.buildService(NextPrayerTileService::class.java).create().get()
        store().clear()
    }

    @After
    fun tearDown() {
        store().clear()
    }

    @Test
    fun `lays out one entry per upcoming prayer, plus a fallback`() {
        val now = System.currentTimeMillis()
        store().apply(
            mapOf(
                WearDataKeys.PRAYER_LOCATION to "Karbala",
                WearDataKeys.PRAYER_SCHEDULE to listOf(
                    "${now + 60_000L}|Maghrib|7:30 pm|Today|Midnight|11:50 pm",
                    "${now + 120_000L}|Fajr|4:30 am|Tomorrow|Sunrise|5:55 am",
                ).joinToString(";"),
                WearDataKeys.UPDATED_AT to now,
            )
        )

        val entries = requestTile().tileTimeline?.timelineEntries.orEmpty()

        assertEquals(3, entries.size)
        // The last entry carries no validity, so the renderer always has something to show.
        assertNotNull(entries.last().layout)
        assertTrue(entries.dropLast(1).all { it.validity != null })
        assertTrue(entries.first().validity!!.endMillis > now)
    }

    @Test
    fun `serves the fallback alone when nothing has synced`() {
        val entries = requestTile().tileTimeline?.timelineEntries.orEmpty()

        assertEquals(1, entries.size)
        assertNotNull(entries.single().layout)
    }

    @Test
    fun `declares the resources version its resources request answers with`() {
        val tile = requestTile()
        val resources = service.onTileResourcesRequest(
            RequestBuilders.ResourcesRequest.Builder().build()
        ).get()

        assertEquals(tile.resourcesVersion, resources.version)
    }

    private fun requestTile(): TileBuilders.Tile = service.onTileRequest(
        RequestBuilders.TileRequest.Builder()
            .setDeviceConfiguration(
                DeviceParametersBuilders.DeviceParameters.Builder()
                    .setScreenWidthDp(192)
                    .setScreenHeightDp(192)
                    .setScreenDensity(2f)
                    .setScreenShape(DeviceParametersBuilders.SCREEN_SHAPE_ROUND)
                    .build()
            )
            .build()
    ).get()

    private fun store() = PrayerDataStore.get(RuntimeEnvironment.getApplication())
}
