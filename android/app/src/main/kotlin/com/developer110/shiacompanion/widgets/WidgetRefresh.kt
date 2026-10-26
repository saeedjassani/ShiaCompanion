package com.developer110.shiacompanion.widgets

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * Re-renders every placed home-screen widget once, the same set the app's
 * "refreshWidgets" channel call refreshes from MainActivity.
 */
suspend fun refreshAllHomeWidgets(context: Context) {
    FavoritesWidget().updateAll(context)
    TodaysRecitationWidget().updateAll(context)
    DailyPrayerTimesWidget().updateAll(context)
    UpcomingPrayerWidget().updateAll(context)
    IslamicCalendarWidget().updateAll(context)
    scheduleNextPrayerWidgetRefresh(context)
    scheduleNextRecitationWidgetRefresh(context)
    scheduleNextCalendarWidgetRefresh(context)
}

/**
 * An app update can leave a placed widget stuck on the launcher's
 * "Problem loading widget" placeholder: the host keeps the views it was
 * last given, and those can reference layouts or drawables the new build
 * changed or removed (the prayer widget's old header layout went away in
 * 4.0.3, and the placed 5x2 widget only recovered when removed and
 * re-added). The app's own refresh only runs once the user opens the app,
 * so do it from the update itself: MY_PACKAGE_REPLACED fires as soon as
 * the new build is installed, before any launch.
 */
class PackageReplacedWidgetRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        val pending = goAsync()
        CoroutineScope(Dispatchers.Default).launch {
            try {
                refreshAllHomeWidgets(context.applicationContext)
            } catch (_: Exception) {
                // A failed refresh just leaves the widgets as they were;
                // it must never crash the update broadcast.
            } finally {
                pending.finish()
            }
        }
    }
}
