package com.developer110.shiacompanion.widgets

import android.content.Context
import android.widget.FrameLayout
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.compose
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Composes every widget at the sizes launchers give them, translates it to
 * RemoteViews and inflates those the way a launcher does, on each Android
 * version the app supports. A widget that throws here would show Glance's
 * error layout, or never leave its loading one, on that version.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 30, 31, 32, 33, 34, 35, 36])
class WidgetRenderTest {
    private val context: Context = ApplicationProvider.getApplicationContext()

    private val sizes = listOf(
        DpSize(150.dp, 60.dp), // 2x1
        DpSize(150.dp, 150.dp), // 2x2
        DpSize(140.dp, 300.dp), // 2x3 on a 21:9 phone
        DpSize(320.dp, 150.dp), // 4x2
        DpSize(320.dp, 260.dp), // 4x3
        DpSize(400.dp, 400.dp), // 5x4
    )

    @Before
    fun clearData() = WidgetTestData.clear(context)

    private fun render(widget: GlanceAppWidget, size: DpSize): List<String> {
        val views = runBlocking { widget.compose(context, size = size) }
        val host = FrameLayout(context)
        val applied = views.apply(context, host)
        host.addView(applied)
        assertFalse("${widget.javaClass.simpleName} at $size is still loading", isLoadingLayout(host))
        return visibleTexts(host)
    }

    private fun assertRenders(widget: GlanceAppWidget, vararg expected: String) {
        for (size in sizes) {
            val texts = render(widget, size)
            for (text in expected) {
                assertTrue(
                    "${widget.javaClass.simpleName} at $size shows \"$text\"; it shows $texts",
                    texts.any { it.contains(text) }
                )
            }
        }
    }

    @Test
    fun `widgets render before the app has published anything`() {
        assertRenders(FavoritesWidget(), "Favorites")
        assertRenders(TodaysRecitationWidget(), "Today's Recitations")
        assertRenders(UpcomingPrayerWidget(), "Prayer Times")
        assertRenders(DailyPrayerTimesWidget(), "Set location")
        assertRenders(IslamicCalendarWidget(), "Open app to refresh")
    }

    @Test
    fun `widgets render the published data`() {
        WidgetTestData.publish(context)
        assertRenders(FavoritesWidget(), "Favorites")
        assertRenders(TodaysRecitationWidget(), "Today's Recitations")
        assertRenders(UpcomingPrayerWidget(), "Zuhr", "12:30")
        assertRenders(DailyPrayerTimesWidget(), "Zuhr", "Asr")
        assertRenders(IslamicCalendarWidget(), "11", "Jumada al-Awwal")
    }

    @Test
    fun `widgets render in a published colour palette`() {
        WidgetTestData.publish(context)
        WidgetTestData.publishPalette(context)
        assertRenders(FavoritesWidget(), "Favorites")
        assertRenders(UpcomingPrayerWidget(), "Zuhr", "12:30")
        assertRenders(DailyPrayerTimesWidget(), "Zuhr", "Asr")
        assertRenders(IslamicCalendarWidget(), "11", "Jumada al-Awwal")
    }
}
