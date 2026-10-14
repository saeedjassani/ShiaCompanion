package com.developer110.shiacompanion.azan

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlin.concurrent.thread

/**
 * Re-arms the stored Azan schedule whenever Android may have dropped it:
 * after a reboot, after an update, and when exact-alarm access comes back
 * (revoking it cancels every exact alarm). A clock or time zone change only
 * re-checks it - alarm clock times are absolute, so they stay right, but
 * ones that are now well in the past are forgotten rather than fired.
 *
 * Alarms that came due while the phone was off are dropped by the same
 * lateness rule the alarm receiver applies, so a phone off for hours doesn't
 * wake up and play a stale Azan.
 */
class AzanRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        val appContext = context.applicationContext
        thread(name = "AzanReschedule") {
            try {
                AzanSchedule.rearm(appContext)
            } catch (e: Exception) {
                AzanLog.error(TAG, "Could not re-arm Azan alarms after ${intent.action}", e)
            } finally {
                pending.finish()
            }
        }
    }

    private companion object {
        const val TAG = "AzanReschedule"
    }
}
