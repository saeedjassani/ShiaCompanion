package com.developer110.shiacompanion

import android.annotation.SuppressLint
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver
import org.json.JSONArray
import org.json.JSONObject
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Stands in for flutter_local_notifications' own boot receiver (declared in
 * its place in AndroidManifest.xml) so a phone that was off for days doesn't
 * wake up to dozens of prayer notifications at once.
 *
 * Android forgets every alarm on reboot, so the plugin keeps its own record
 * of scheduled notifications and re-arms all of them at boot - including the
 * ones whose time passed while the phone was off, which AlarmManager then
 * fires immediately, all together. A prayer or prayer-relative reminder
 * that's more than [STALE_AFTER_MILLIS] late is no use to anyone, so those
 * are dropped from the record first; the plugin's receiver then re-arms the
 * rest exactly as before. The schedule itself refills the next time the app
 * opens (setUpNotifications).
 *
 * Any failure leaves the record untouched, so the worst case is the old
 * burst, never a lost upcoming notification.
 */
class StaleNotificationBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            dropStaleNotifications(context)
        } catch (e: Exception) {
            Log.e(TAG, "Could not prune stale notifications", e)
        }
        ScheduledNotificationBootReceiver().onReceive(context, intent)
    }

    @SuppressLint("ApplySharedPref")
    private fun dropStaleNotifications(context: Context) {
        // flutter_local_notifications' own storage: a Gson-serialised list of
        // its NotificationDetails, under this name and key.
        val prefs = context.getSharedPreferences(PLUGIN_CACHE, Context.MODE_PRIVATE)
        val json = prefs.getString(PLUGIN_CACHE, null) ?: return
        val scheduled = JSONArray(json)
        val now = System.currentTimeMillis()

        val kept = JSONArray()
        var dropped = 0
        for (i in 0 until scheduled.length()) {
            val notification = scheduled.getJSONObject(i)
            if (isStale(notification, now)) {
                dropped++
            } else {
                kept.put(notification)
            }
        }
        if (dropped == 0) return

        // commit, not apply: the plugin reads this same record right after.
        prefs.edit().putString(PLUGIN_CACHE, kept.toString()).commit()
        Log.i(TAG, "Dropped $dropped notification(s) missed while the phone was off")
    }

    private fun isStale(notification: JSONObject, now: Long): Boolean {
        // Only prayer times and zikr reminders: the "reopen the app" nudge is
        // still worth showing late, since a phone off for days has likely run
        // past the end of its prayer schedule.
        val channel = notification.optString("channelId")
        if (!channel.startsWith("prayer_") && channel != "zikr_reminders") return false

        // Repeating notifications are re-armed for their next occurrence, not
        // this one, so they're never stale.
        if (REPEAT_FIELDS.any { notification.has(it) && !notification.isNull(it) }) {
            return false
        }

        val fireAt = fireTimeMillis(notification) ?: return false
        return now - fireAt > STALE_AFTER_MILLIS
    }

    private fun fireTimeMillis(notification: JSONObject): Long? {
        val dateTime = notification.optString("scheduledDateTime")
        val zone = notification.optString("timeZoneName")
        if (dateTime.isNotEmpty() && zone.isNotEmpty()) {
            return LocalDateTime.parse(dateTime)
                .atZone(ZoneId.of(zone))
                .toInstant()
                .toEpochMilli()
        }
        if (notification.has("millisecondsSinceEpoch") &&
            !notification.isNull("millisecondsSinceEpoch")
        ) {
            return notification.getLong("millisecondsSinceEpoch")
        }
        return null
    }

    companion object {
        private const val TAG = "StaleNotifBootReceiver"
        private const val PLUGIN_CACHE = "scheduled_notifications"

        /** How late a notification can still be shown after a reboot. */
        private const val STALE_AFTER_MILLIS = 10 * 60 * 1000L

        private val REPEAT_FIELDS = listOf(
            "repeatInterval",
            "repeatIntervalMilliseconds",
            "scheduledNotificationRepeatFrequency",
            "matchDateTimeComponents",
        )
    }
}
