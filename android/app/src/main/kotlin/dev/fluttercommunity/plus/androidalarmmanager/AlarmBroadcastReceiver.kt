package dev.fluttercommunity.plus.androidalarmmanager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.developer110.shiacompanion.R
import com.developer110.shiacompanion.azan.AzanLog
import com.developer110.shiacompanion.azan.AzanPlayRequest
import com.developer110.shiacompanion.azan.AzanPlayerService
import com.developer110.shiacompanion.azan.AzanSchedule
import org.json.JSONObject

/**
 * Stands in for android_alarm_manager_plus's receiver, under its exact name,
 * for the Azan alarms that plugin scheduled before an update replaced it.
 *
 * Those alarms are already armed in Android and point at this class name.
 * Without it they would silently drop, and anyone whose phone updated
 * overnight would hear no Azan until they next opened the app. They play
 * natively here until then - and only until then: once the app has scheduled
 * through [AzanSchedule], which also cancels them, any that still arrive are
 * ignored, so an Azan can never play twice.
 */
class AlarmBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", -1)
        if (AzanSchedule.isAdopted(context)) {
            AzanLog.info(TAG, "Ignoring legacy Azan alarm $id: the native schedule has taken over")
            return
        }
        val params = try {
            intent.getStringExtra("params")?.let(::JSONObject)
        } catch (e: Exception) {
            null
        }
        val prayerName = params?.optString("prayerName")?.takeIf { it.isNotEmpty() } ?: "Prayer"
        val customFilePath = params?.optString("customFilePath")?.takeIf { it.isNotEmpty() }
        AzanLog.info(TAG, "Playing legacy Azan alarm $id for $prayerName")
        AzanPlayerService.play(
            context,
            AzanPlayRequest(
                prayerName = prayerName,
                playingTitle = context.getString(R.string.azan_playing_fallback, prayerName),
                pausedTitle = context.getString(R.string.azan_paused_fallback, prayerName),
                customFilePath = customFilePath,
            ),
            fromAlarm = true,
        )
    }

    private companion object {
        const val TAG = "LegacyAzanAlarm"
    }
}
