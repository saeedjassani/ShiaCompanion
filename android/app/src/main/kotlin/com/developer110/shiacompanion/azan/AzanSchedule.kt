package com.developer110.shiacompanion.azan

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * One Full Azan / Custom Audio alarm: what to play, for which prayer, when.
 *
 * [id] is the paired prayer notification's id (see setUpNotifications), so a
 * prayer's notification and its Azan are cancelled and replaced together.
 */
data class AzanAlarm(
    val id: Int,
    val fireAtMillis: Long,
    val prayerName: String,
    val playingTitle: String,
    val pausedTitle: String,
    val customFilePath: String?,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("id", id)
        .put("at", fireAtMillis)
        .put("prayer", prayerName)
        .put("title", playingTitle)
        .put("pausedTitle", pausedTitle)
        .put("custom", customFilePath ?: JSONObject.NULL)

    companion object {
        fun fromJson(json: JSONObject) = AzanAlarm(
            id = json.getInt("id"),
            fireAtMillis = json.getLong("at"),
            prayerName = json.getString("prayer"),
            playingTitle = json.getString("title"),
            pausedTitle = json.optString("pausedTitle", json.getString("title")),
            customFilePath = if (json.isNull("custom")) null else json.getString("custom"),
        )
    }
}

/** What a delivered alarm should do. */
enum class AzanDelivery {
    /** Play it, and forget it so it can't play twice. */
    PLAY,

    /** Too late to be of use: forget it. */
    LATE,

    /** Before its time - only a clock moved back can do that: keep it and re-arm it. */
    EARLY,

    /** Not in the schedule (cancelled, replaced, or already played): ignore it. */
    UNSCHEDULED,
}

/**
 * The rules for whether a fired alarm should play, kept free of Android so
 * they can be unit tested.
 *
 * Playing at the wrong moment is as bad as not playing, so an alarm only plays
 * if the schedule still holds that exact alarm (an id is reused day to day,
 * and a rescheduled prayer gets a new time), it isn't more than
 * [LATE_LIMIT_MILLIS] late - the same limit StaleNotificationBootReceiver
 * applies to the prayer notifications themselves after a reboot - and it
 * isn't more than [EARLY_LIMIT_MILLIS] early. Android never delivers an alarm
 * clock early; a delivery queued while the clock had jumped ahead can still
 * arrive after it has been set back.
 */
object AzanScheduleRules {
    const val LATE_LIMIT_MILLIS = 10 * 60 * 1000L
    const val EARLY_LIMIT_MILLIS = 60 * 1000L

    fun isStale(alarm: AzanAlarm, nowMillis: Long): Boolean =
        nowMillis - alarm.fireAtMillis > LATE_LIMIT_MILLIS

    /** The alarms still worth arming at [nowMillis]. */
    fun armable(alarms: List<AzanAlarm>, nowMillis: Long): List<AzanAlarm> =
        alarms.filterNot { isStale(it, nowMillis) }

    /** What a delivery of the alarm ([id], [fireAtMillis]) should do at [nowMillis]. */
    fun decide(
        alarms: List<AzanAlarm>,
        id: Int,
        fireAtMillis: Long,
        nowMillis: Long,
    ): AzanDelivery {
        val alarm = alarms.firstOrNull { it.id == id && it.fireAtMillis == fireAtMillis }
            ?: return AzanDelivery.UNSCHEDULED
        if (isStale(alarm, nowMillis)) return AzanDelivery.LATE
        if (alarm.fireAtMillis - nowMillis > EARLY_LIMIT_MILLIS) return AzanDelivery.EARLY
        return AzanDelivery.PLAY
    }

    fun parse(json: String?): List<AzanAlarm> {
        if (json.isNullOrEmpty()) return emptyList()
        val array = JSONArray(json)
        return (0 until array.length()).map { AzanAlarm.fromJson(array.getJSONObject(it)) }
    }

    fun serialize(alarms: List<AzanAlarm>): String =
        JSONArray().apply { alarms.forEach { put(it.toJson()) } }.toString()
}

/**
 * The Full Azan schedule, kept natively so it can be played - and re-armed
 * after a reboot, an update or a force-stop - without starting Flutter.
 *
 * The stored list is the only source of truth: an alarm Android delivers that
 * isn't in it (cancelled, or since replaced) never plays. Every write goes
 * through [lock] and commit(), and alarms are armed after the list that
 * vouches for them is on disk.
 */
object AzanSchedule {
    private const val TAG = "AzanSchedule"
    private const val PREFS = "shia_companion_azan"
    private const val KEY_ALARMS = "alarms"
    private const val KEY_LABELS = "labels"

    /** Set once Dart has scheduled through here; see the legacy alarm receiver. */
    private const val KEY_ADOPTED = "adopted"

    const val ACTION_FIRE = "com.developer110.shiacompanion.azan.FIRE"
    const val EXTRA_ID = "id"
    const val EXTRA_FIRE_AT = "fireAt"

    private val lock = Any()

    fun alarms(context: Context): List<AzanAlarm> = synchronized(lock) {
        read(context)
    }

    /** Replaces the whole schedule, cancelling any alarm that isn't in [alarms]. */
    fun replace(context: Context, alarms: List<AzanAlarm>, labels: AzanLabels?) {
        val previous: List<AzanAlarm>
        synchronized(lock) {
            previous = read(context)
            val editor = prefs(context).edit()
                .putString(KEY_ALARMS, AzanScheduleRules.serialize(alarms))
                .putBoolean(KEY_ADOPTED, true)
            labels?.let { editor.putString(KEY_LABELS, it.toJson().toString()) }
            editor.commit()
        }
        val keep = alarms.map { it.id }.toSet()
        previous.filter { it.id !in keep }.forEach { cancelAlarm(context, it.id) }
        arm(context, alarms)
    }

    /** Clears the schedule and cancels its alarms, plus any legacy alarm for [legacyIds]. */
    fun clear(context: Context, legacyIds: List<Int>) {
        val previous: List<AzanAlarm>
        synchronized(lock) {
            previous = read(context)
            prefs(context).edit()
                .remove(KEY_ALARMS)
                .putBoolean(KEY_ADOPTED, true)
                .commit()
        }
        previous.forEach { cancelAlarm(context, it.id) }
        legacyIds.forEach { cancelLegacyAlarm(context, it) }
    }

    /**
     * Arms every scheduled alarm that is still due, and forgets the rest.
     *
     * Android drops all of an app's alarms on a reboot, a force-stop or a
     * revoked exact-alarm permission, and nothing tells the app about the
     * last two - so this runs at every launch as well as from
     * AzanRescheduleReceiver. Setting an alarm that already exists just
     * replaces it, so running it again is harmless.
     */
    fun rearm(context: Context) {
        val now = System.currentTimeMillis()
        val due: List<AzanAlarm>
        synchronized(lock) {
            val all = read(context)
            due = AzanScheduleRules.armable(all, now)
            if (due.size != all.size) {
                prefs(context).edit()
                    .putString(KEY_ALARMS, AzanScheduleRules.serialize(due))
                    .commit()
            }
        }
        arm(context, due)
    }

    /**
     * Decides what this delivery should do, and records it: a played or late
     * alarm leaves the schedule so it can never play twice, and an early one
     * is armed again for its real time. Returns the alarm only when it should
     * play now.
     */
    fun take(context: Context, id: Int, fireAtMillis: Long): Pair<AzanDelivery, AzanAlarm?> {
        val alarm: AzanAlarm?
        val decision: AzanDelivery
        synchronized(lock) {
            val all = read(context)
            decision = AzanScheduleRules.decide(all, id, fireAtMillis, System.currentTimeMillis())
            alarm = all.firstOrNull { it.id == id && it.fireAtMillis == fireAtMillis }
            if (decision == AzanDelivery.PLAY || decision == AzanDelivery.LATE) {
                val remaining = all.filterNot { it.id == id && it.fireAtMillis == fireAtMillis }
                prefs(context).edit()
                    .putString(KEY_ALARMS, AzanScheduleRules.serialize(remaining))
                    .commit()
            }
        }
        if (decision == AzanDelivery.EARLY && alarm != null) arm(context, listOf(alarm))
        return decision to alarm.takeIf { decision == AzanDelivery.PLAY }
    }

    fun hasAlarm(context: Context, id: Int): Boolean = synchronized(lock) {
        read(context).any { it.id == id }
    }

    /** Whether Dart has ever scheduled through here, i.e. legacy alarms are obsolete. */
    fun isAdopted(context: Context): Boolean =
        prefs(context).getBoolean(KEY_ADOPTED, false)

    fun labels(context: Context): AzanLabels? =
        prefs(context).getString(KEY_LABELS, null)?.let { AzanLabels.fromJson(JSONObject(it)) }

    fun saveLabels(context: Context, labels: AzanLabels) {
        prefs(context).edit().putString(KEY_LABELS, labels.toJson().toString()).apply()
    }

    private fun arm(context: Context, alarms: List<AzanAlarm>) {
        if (alarms.isEmpty()) return
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            // Dart only schedules with exact alarms (azanPlaysAutomatically),
            // so this means access was revoked since. Android has already
            // dropped the alarms; AzanRescheduleReceiver re-arms them when it
            // comes back, and the notification still offers a tap to play.
            AzanLog.warn(TAG, "Exact alarms not allowed; ${alarms.size} Azan alarm(s) left unarmed")
            return
        }
        val show = launchAppIntent(context)
        var failed = 0
        for (alarm in alarms) {
            try {
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(alarm.fireAtMillis, show),
                    firePendingIntent(context, alarm.id, alarm.fireAtMillis),
                )
            } catch (e: SecurityException) {
                failed++
                if (failed == 1) AzanLog.error(TAG, "Could not arm Azan alarm ${alarm.id}", e)
            }
        }
        Log.i(TAG, "Armed ${alarms.size - failed} Azan alarm(s)")
    }

    private fun cancelAlarm(context: Context, id: Int) {
        val intent = fireIntent(context, id, 0L)
        val pending = PendingIntent.getBroadcast(
            context, id, intent, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        context.getSystemService(AlarmManager::class.java).cancel(pending)
        pending.cancel()
    }

    /** Cancels an alarm android_alarm_manager_plus scheduled before this replaced it. */
    private fun cancelLegacyAlarm(context: Context, id: Int) {
        val intent = Intent().setClassName(context, LEGACY_RECEIVER)
        val pending = PendingIntent.getBroadcast(
            context, id, intent, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        ) ?: return
        context.getSystemService(AlarmManager::class.java).cancel(pending)
        pending.cancel()
    }

    private fun firePendingIntent(context: Context, id: Int, fireAtMillis: Long): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            id,
            fireIntent(context, id, fireAtMillis),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    // The action and component identify the PendingIntent (extras don't), so
    // cancelAlarm can rebuild it without knowing the fire time.
    private fun fireIntent(context: Context, id: Int, fireAtMillis: Long) =
        Intent(context, AzanAlarmReceiver::class.java)
            .setAction(ACTION_FIRE)
            .putExtra(EXTRA_ID, id)
            .putExtra(EXTRA_FIRE_AT, fireAtMillis)

    fun launchAppIntent(context: Context): PendingIntent {
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?: Intent().setClassName(context, "com.developer110.shia_companion.MainActivity")
        return PendingIntent.getActivity(
            context, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun read(context: Context): List<AzanAlarm> = try {
        AzanScheduleRules.parse(prefs(context).getString(KEY_ALARMS, null))
    } catch (e: Exception) {
        AzanLog.error(TAG, "Unreadable Azan schedule; treating it as empty", e)
        emptyList()
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    const val LEGACY_RECEIVER =
        "dev.fluttercommunity.plus.androidalarmmanager.AlarmBroadcastReceiver"
}

/** The words the playback notification needs, in the reader's language. */
data class AzanLabels(
    val pause: String,
    val resume: String,
    val stop: String,
    val channelName: String,
) {
    fun toJson(): JSONObject = JSONObject()
        .put("pause", pause)
        .put("resume", resume)
        .put("stop", stop)
        .put("channel", channelName)

    companion object {
        fun fromJson(json: JSONObject) = AzanLabels(
            pause = json.getString("pause"),
            resume = json.getString("resume"),
            stop = json.getString("stop"),
            channelName = json.getString("channel"),
        )

        fun fromMap(map: Map<*, *>?): AzanLabels? {
            map ?: return null
            return AzanLabels(
                pause = map["pause"] as? String ?: return null,
                resume = map["resume"] as? String ?: return null,
                stop = map["stop"] as? String ?: return null,
                channelName = map["channel"] as? String ?: return null,
            )
        }
    }
}
