package com.developer110.shiacompanion.azan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Fires at prayer time and hands the Azan to [AzanPlayerService] - natively,
 * without starting Flutter. Starting an engine here used to wake
 * audio_service's cached engine too, which ran the app's main() headless and
 * left it stuck behind the alarm's own audio setup, so opening the app during
 * the Azan hung on the splash screen.
 */
class AzanAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != AzanSchedule.ACTION_FIRE) return
        val id = intent.getIntExtra(AzanSchedule.EXTRA_ID, -1)
        val fireAt = intent.getLongExtra(AzanSchedule.EXTRA_FIRE_AT, -1L)

        val (decision, alarm) = AzanSchedule.take(context, id, fireAt)
        val offBy = (System.currentTimeMillis() - fireAt) / 1000
        when (decision) {
            AzanDelivery.LATE -> AzanLog.warn(TAG, "Azan $id delivered ${offBy}s late; not playing")
            AzanDelivery.EARLY -> AzanLog.warn(TAG, "Azan $id delivered ${-offBy}s early; re-armed")
            AzanDelivery.UNSCHEDULED -> AzanLog.info(TAG, "Azan $id is no longer scheduled; not playing")
            AzanDelivery.PLAY -> {}
        }
        if (alarm == null) return
        AzanPlayerService.play(
            context,
            AzanPlayRequest(
                prayerName = alarm.prayerName,
                playingTitle = alarm.playingTitle,
                pausedTitle = alarm.pausedTitle,
                customFilePath = alarm.customFilePath,
            ),
            fromAlarm = true,
        )
    }

    private companion object {
        const val TAG = "AzanAlarmReceiver"
    }
}
