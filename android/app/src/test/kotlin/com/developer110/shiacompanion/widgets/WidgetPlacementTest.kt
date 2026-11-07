package com.developer110.shiacompanion.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.util.SizeF
import android.view.View
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.test.core.app.ApplicationProvider
import androidx.work.Configuration
import androidx.work.WorkManager
import com.developer110.shiacompanion.R
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import kotlinx.coroutines.runBlocking
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowAppWidgetManager

/**
 * Places each widget the way a launcher does - bind an id, send
 * APPWIDGET_UPDATE to its receiver - and waits for the real path the app
 * takes from there (the receiver, WorkManager's job, Glance's session,
 * AppWidgetManager.updateAppWidget) to replace the loading spinner, on each
 * Android version the app supports. Also covers the app's own refresh
 * (refreshAll, as the Flutter side's "refreshWidgets" does).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29, 30, 31, 32, 33, 34, 35, 36])
class WidgetPlacementTest {
    private val context: Context = ApplicationProvider.getApplicationContext()
    private val appWidgetManager = AppWidgetManager.getInstance(context)
    private val shadowManager: ShadowAppWidgetManager = shadowOf(appWidgetManager)

    @Before
    fun setUp() {
        WidgetTestData.clear(context)
        // Robolectric doesn't run androidx.startup's provider, which
        // initialises WorkManager on a device.
        try {
            // On a device the app's process is its default one. Robolectric
            // names its process differently from the ApplicationInfo, which
            // makes WorkManager think it's in a secondary process and leave
            // Glance's session job to JobScheduler, which never runs here.
            WorkManager.initialize(
                context,
                Configuration.Builder().setDefaultProcessName(Application.getProcessName()).build()
            )
        } catch (_: IllegalStateException) {
            // Set up by an earlier test in this sandbox, still holding that
            // test's context; hence one test per SDK below.
        }
    }

    private fun place(
        receiver: GlanceAppWidgetReceiver,
        widthDp: Int,
        heightDp: Int,
        infoRes: Int
    ): Int {
        val component = ComponentName(context, receiver.javaClass)
        val info = AppWidgetProviderInfo().apply {
            provider = component
            initialLayout = androidx.glance.appwidget.R.layout.glance_default_loading_layout
        }
        assertNotNull(context.resources.getXml(infoRes))
        shadowManager.addInstalledProvider(info)
        // What a launcher reports: min/max per orientation, and on 31+ the
        // exact sizes it lays the widget out at.
        val options = Bundle().apply {
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, widthDp)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, widthDp + 40)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, heightDp - 20)
            putInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, heightDp)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                putParcelableArrayList(
                    AppWidgetManager.OPTION_APPWIDGET_SIZES,
                    arrayListOf(
                        SizeF(widthDp.toFloat(), heightDp - 20f),
                        SizeF(widthDp + 40f, heightDp.toFloat())
                    )
                )
            }
        }
        val id = nextId.getAndIncrement()
        shadowManager.setAllowedToBindAppWidgets(true)
        assertTrue(appWidgetManager.bindAppWidgetIdIfAllowed(id, component, options))
        // The host shows initialLayout until the provider's first update.
        appWidgetManager.updateAppWidget(
            id,
            android.widget.RemoteViews(context.packageName, info.initialLayout)
        )
        assertTrue(isLoadingLayout(shadowManager.getViewFor(id)))

        deliver(
            receiver,
            Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .setComponent(component)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(id))
        )
        return id
    }

    /**
     * Calls [receiver] the way the system delivers a broadcast: with a
     * PendingResult, so its goAsync() has one to finish. (Robolectric's
     * sendBroadcast doesn't reach these manifest receivers by component.)
     */
    private fun deliver(receiver: BroadcastReceiver, intent: Intent) {
        val create = Class.forName("org.robolectric.shadows.ShadowBroadcastPendingResult")
            .getDeclaredMethod(
                "create",
                Int::class.javaPrimitiveType, String::class.java, Bundle::class.java,
                Boolean::class.javaPrimitiveType
            )
            .apply { isAccessible = true }
        val pendingResult = create.invoke(null, 0, null, null, false)
        BroadcastReceiver::class.java
            .getMethod("setPendingResult", BroadcastReceiver.PendingResult::class.java)
            .invoke(receiver, pendingResult)
        receiver.onReceive(context, intent)
    }

    /**
     * Runs the main looper, where Glance's sessions run, until [done] or 20 s.
     * Their frame clock waits with delay(), so the looper's simulated clock
     * has to move too.
     */
    private fun runMainLooperUntil(done: () -> Boolean): Boolean {
        val deadline = System.currentTimeMillis() + 20_000
        while (System.currentTimeMillis() < deadline) {
            shadowOf(Looper.getMainLooper()).idleFor(java.time.Duration.ofMillis(100))
            if (done()) return true
            Thread.sleep(20)
        }
        return false
    }

    /** Waits until [id] has left the loading spinner and shows [expected] but not [absent]. */
    private fun awaitContent(id: Int, what: String, expected: String, absent: String? = null): View {
        var view: View? = null
        val shown = runMainLooperUntil {
            view = shadowManager.getViewFor(id)
            view?.let {
                val texts = visibleTexts(it)
                !isLoadingLayout(it) && texts.any { t -> expected in t } &&
                    (absent == null || texts.none { t -> absent in t })
            } == true
        }
        if (shown) return view!!
        val work = WorkManager.getInstance(context).getWorkInfosForUniqueWork("appWidget-$id").get()
        val state = view?.let { if (isLoadingLayout(it)) "still on its loading spinner" else "showing ${visibleTexts(it)}" }
        throw AssertionError("$what is $state after 20 s; its session work: $work")
    }

    private fun assertShows(view: View, what: String, expected: String, absent: String? = null) {
        val texts = visibleTexts(view)
        if (absent != null) {
            assertFalse("$what still shows \"$absent\": $texts", texts.any { absent in it })
        }
        assertFalse(
            "$what shows Glance's error layout: $texts",
            texts.any { it.contains("Can't show content") || it.contains("Glance App Widget Error") }
        )
        assertTrue("$what shows \"$expected\"; it shows $texts", texts.any { expected in it })
    }

    /** A widget, its provider info, what it shows once the app has published, and what it shows before. */
    private class Case(
        val receiver: GlanceAppWidgetReceiver,
        val infoRes: Int,
        val published: String,
        val unpublished: String
    )

    private val widgets = listOf(
        // The list widgets' rows live in a collection adapter, which no host
        // fills in here, so their check is that the placeholder has gone.
        Case(FavoritesWidgetReceiver(), R.xml.favorites_widget_info, "Favorites", "No favorites yet"),
        Case(TodaysRecitationWidgetReceiver(), R.xml.recitation_widget_info, "Today's Recitations", "Open app to refresh"),
        Case(UpcomingPrayerWidgetReceiver(), R.xml.prayer_widget_info, "Zuhr", "Set location"),
        Case(DailyPrayerTimesWidgetReceiver(), R.xml.daily_prayer_widget_info, "Asr", "Set location"),
        Case(IslamicCalendarWidgetReceiver(), R.xml.calendar_widget_info, "Jumada al-Awwal", "Open app to refresh"),
    )

    /** [widget].refreshAll() - what the app's "refreshWidgets" does - with the main looper running. */
    private fun refreshAll(widget: GlanceAppWidget) {
        var error: Throwable? = null
        var done = false
        Thread {
            try {
                runBlocking { widget.refreshAll(context) }
            } catch (t: Throwable) {
                error = t
            }
            done = true
        }.start()
        assertTrue("${widget.javaClass.simpleName}.refreshAll() didn't return", runMainLooperUntil { done })
        error?.let { throw it }
    }

    // One test per SDK: WorkManager outlives a test in Robolectric's sandbox
    // and keeps the first test's context, so a second test's widgets would
    // be invisible to it.
    @Test
    fun `widgets leave their loading spinner when placed, and show what the app publishes`() {
        // Placed before the app has ever published: each shows its own
        // "open the app" text, not the spinner.
        val early = widgets.map { case ->
            val what = case.receiver.javaClass.simpleName
            val id = place(case.receiver, 150, 150, case.infoRes)
            assertShows(awaitContent(id, what, case.unpublished), what, case.unpublished)
            id
        }

        // The app then publishes and refreshes, as MainActivity's
        // "refreshWidgets" does, while those widgets' sessions are still up:
        // they pick the data up.
        WidgetTestData.publish(context)
        widgets.forEach { refreshAll(it.receiver.glanceAppWidget) }
        early.zip(widgets).forEach { (id, case) ->
            val what = "${case.receiver.javaClass.simpleName} after the app's refresh"
            assertShows(awaitContent(id, what, case.published, case.unpublished), what, case.published, case.unpublished)
        }

        // And widgets placed once there is data show it from the start, at
        // the sizes launchers commonly give them.
        for (case in widgets) {
            for ((width, height) in listOf(150 to 150, 320 to 150, 320 to 260)) {
                val what = "${case.receiver.javaClass.simpleName} at ${width}x$height"
                val id = place(case.receiver, width, height, case.infoRes)
                assertShows(awaitContent(id, what, case.published, case.unpublished), what, case.published, case.unpublished)
            }
        }
    }

    private companion object {
        // Unique across SDKs too: Glance keys its sessions by widget id.
        val nextId = java.util.concurrent.atomic.AtomicInteger(1)
    }
}
