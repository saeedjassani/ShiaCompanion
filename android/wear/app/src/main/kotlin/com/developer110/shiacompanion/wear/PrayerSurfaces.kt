package com.developer110.shiacompanion.wear

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import androidx.wear.tiles.TileService
import androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester
import com.developer110.shiacompanion.wear.complication.NextPrayerComplicationService
import com.developer110.shiacompanion.wear.tile.NextPrayerTileService

private const val ACTION_REFRESH_PRAYER_SURFACES =
    "com.developer110.shiacompanion.wear.REFRESH_PRAYER_SURFACES"

/**
 * Keeps the tile and the complication showing the right prayer.
 *
 * Both render the *next* prayer, so both go stale the moment one passes — which happens on
 * the watch's own clock, with no sync involved. An exact alarm at each prayer time is what
 * rolls them over; the tile's own timeline covers the case where the alarm is dropped.
 */
object PrayerSurfaces {

    fun refresh(context: Context) {
        val appContext = context.applicationContext

        TileService.getUpdater(appContext).requestUpdate(NextPrayerTileService::class.java)

        ComplicationDataSourceUpdateRequester
            .create(
                appContext,
                ComponentName(appContext, NextPrayerComplicationService::class.java)
            )
            .requestUpdateAll()
    }

    fun scheduleNextRefresh(context: Context) {
        val appContext = context.applicationContext
        val triggerAt = PrayerDataStore.get(appContext).nextPrayer()?.epochMillis ?: return
        if (triggerAt <= System.currentTimeMillis()) return

        val alarmManager =
            appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = PendingIntent.getBroadcast(
            appContext,
            0,
            Intent(appContext, PrayerRefreshReceiver::class.java)
                .setAction(ACTION_REFRESH_PRAYER_SURFACES),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent
            )
        } catch (_: SecurityException) {
            // Exact alarms can be revoked; a slightly late roll-over beats none.
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }
}

class PrayerRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_REFRESH_PRAYER_SURFACES, Intent.ACTION_BOOT_COMPLETED -> {
                PrayerSurfaces.refresh(context)
                PrayerSurfaces.scheduleNextRefresh(context)
            }
        }
    }
}
