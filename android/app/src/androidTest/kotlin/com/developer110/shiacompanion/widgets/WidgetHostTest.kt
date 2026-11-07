// runner 1.3.0's own AndroidJUnit4, deprecated: androidx.test.ext:junit pulls
// in a test-core whose manifest predates Android 12 (see build.gradle).
@file:Suppress("DEPRECATION")

package com.developer110.shiacompanion.widgets

import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.util.SizeF
import android.view.View
import android.view.ViewGroup
import android.widget.ProgressBar
import android.widget.TextView
import androidx.test.runner.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Hosts each home-screen widget on a real device or emulator the way a
 * launcher does - an AppWidgetHost, a bound id, the system's own
 * APPWIDGET_UPDATE - and waits for it to leave Glance's loading spinner.
 *
 * Run by .github/workflows/android-widgets.yml on one emulator per API level.
 * Locally: `./gradlew :app:connectedDebugAndroidTest` with a device attached.
 */
@RunWith(AndroidJUnit4::class)
class WidgetHostTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context: Context = instrumentation.targetContext
    private val manager = AppWidgetManager.getInstance(context)
    private lateinit var host: AppWidgetHost
    private val ids = mutableListOf<Int>()

    @Before
    fun setUp() {
        // What a launcher holds as the default home app; any other host needs
        // the user's (here the shell's) leave to bind widgets.
        val output = instrumentation.uiAutomation
            .executeShellCommand("appwidget grantbind --package ${context.packageName} --user current")
        // Read to the end, so the command has finished before the first bind.
        ParcelFileDescriptor.AutoCloseInputStream(output).use { it.readBytes() }
        instrumentation.runOnMainSync {
            host = AppWidgetHost(context, HOST_ID)
            host.startListening()
        }
    }

    @After
    fun tearDown() {
        instrumentation.runOnMainSync {
            ids.forEach { host.deleteAppWidgetId(it) }
            host.stopListening()
        }
    }

    private fun publishData() {
        val hour = 60L * 60L * 1000L
        val now = System.currentTimeMillis()
        val schedule = listOf("Zuhr" to "12:30 pm", "Asr" to "3:45 pm", "Maghrib" to "6:10 pm", "Isha" to "7:30 pm")
            .mapIndexed { index, (name, time) -> "${now + (index + 1) * 2 * hour}|$name|$time|Today" }
            .joinToString(";")
        context.getSharedPreferences("shia_companion_widgets", Context.MODE_PRIVATE).edit()
            .putString("sc_prayer_location", "Karachi")
            .putString("sc_prayer_schedule", schedule)
            .putString("sc_favorites_item_1", "Dua Ahad")
            .putString("sc_favorites_url_1", "/zikr/dua-ahad")
            .commit()
    }

    /** Binds [receiver]'s widget at [widthDp]x[heightDp] and returns the view a launcher would show. */
    private fun place(receiver: Class<*>, widthDp: Int, heightDp: Int): AppWidgetHostView {
        val component = ComponentName(context, receiver)
        val info = manager.installedProviders.firstOrNull { it.provider == component }
            ?: error("$component is not an installed widget provider")
        val options = Bundle().apply {
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, widthDp)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, widthDp + 40)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, heightDp - 20)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, heightDp)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                putParcelableArrayList(
                    AppWidgetManager.OPTION_APPWIDGET_SIZES,
                    arrayListOf(SizeF(widthDp.toFloat(), heightDp - 20f), SizeF(widthDp + 40f, heightDp.toFloat()))
                )
            }
        }
        lateinit var view: AppWidgetHostView
        instrumentation.runOnMainSync {
            val id = host.allocateAppWidgetId()
            ids += id
            assertTrue(
                "Could not bind $component; is the shell's grantbind missing?",
                manager.bindAppWidgetIdIfAllowed(id, component, options)
            )
            view = host.createView(context, id, info)
            val density = context.resources.displayMetrics.density
            view.measure(
                View.MeasureSpec.makeMeasureSpec((widthDp * density).toInt(), View.MeasureSpec.EXACTLY),
                View.MeasureSpec.makeMeasureSpec((heightDp * density).toInt(), View.MeasureSpec.EXACTLY)
            )
            view.layout(0, 0, view.measuredWidth, view.measuredHeight)
        }
        return view
    }

    private fun texts(view: View): List<String> {
        if (view.visibility != View.VISIBLE) return emptyList()
        val own = if (view is TextView && view.text.isNotBlank()) listOf(view.text.toString()) else emptyList()
        if (view !is ViewGroup) return own
        return own + (0 until view.childCount).flatMap { texts(view.getChildAt(it)) }
    }

    private fun loading(view: View): Boolean = when {
        view is ProgressBar && view.visibility == View.VISIBLE -> true
        view is ViewGroup -> (0 until view.childCount).any { loading(view.getChildAt(it)) }
        else -> false
    }

    private fun awaitContent(view: AppWidgetHostView, what: String, expected: String, absent: String?) {
        val deadline = System.currentTimeMillis() + TIMEOUT_MILLIS
        var shown = emptyList<String>()
        var spinning = true
        while (System.currentTimeMillis() < deadline) {
            instrumentation.runOnMainSync {
                spinning = loading(view)
                shown = texts(view)
            }
            if (!spinning && shown.any { expected in it } && (absent == null || shown.none { absent in it })) return
            Thread.sleep(250)
        }
        fail(
            "$what on API ${Build.VERSION.SDK_INT}: " +
                (if (spinning) "still on the loading spinner" else "not showing \"$expected\" without \"$absent\"") +
                " after ${TIMEOUT_MILLIS / 1000} s; it shows $shown"
        )
    }

    @Test
    fun everyWidgetLeavesItsLoadingSpinner() {
        publishData()
        // What each shows once rendered, and the placeholder it mustn't
        // still show. A list's rows are drawn by a collection adapter only
        // once the view is on screen, so for Favorites the check is that its
        // "No favorites yet" has gone.
        val widgets = listOf(
            Triple(FavoritesWidgetReceiver::class.java, "Favorites", "No favorites yet"),
            Triple(TodaysRecitationWidgetReceiver::class.java, "Today's Recitations", null),
            Triple(UpcomingPrayerWidgetReceiver::class.java, "Zuhr", "Set location"),
            Triple(DailyPrayerTimesWidgetReceiver::class.java, "Asr", "Set location"),
            Triple(IslamicCalendarWidgetReceiver::class.java, "Islamic Calendar", null),
        )
        for ((receiver, expected, absent) in widgets) {
            for ((width, height) in listOf(150 to 150, 320 to 180)) {
                val what = "${receiver.simpleName} at ${width}x$height"
                awaitContent(place(receiver, width, height), what, expected, absent)
            }
        }
    }

    private companion object {
        const val HOST_ID = 4711
        const val TIMEOUT_MILLIS = 30_000L
    }
}
