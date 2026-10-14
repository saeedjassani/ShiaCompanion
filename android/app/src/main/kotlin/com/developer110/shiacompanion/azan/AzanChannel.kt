package com.developer110.shiacompanion.azan

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * The app's side of native Azan playback: the schedule, playback controls and
 * the state the "Azan is playing" banner shows. AzanPlaybackService in Dart
 * is the only caller.
 */
object AzanChannel {
    private const val NAME = "shia_companion/azan"
    private const val TAG = "AzanChannel"

    // One thread, so a clear and the replace that follows it land in the
    // order Dart sent them - and off the main thread, which Flutter shares.
    private val scheduleExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null

    fun attach(context: Context, messenger: BinaryMessenger) {
        val appContext = context.applicationContext
        val methodChannel = MethodChannel(messenger, NAME)
        methodChannel.setMethodCallHandler { call, result -> handle(appContext, call, result) }
        channel = methodChannel
        AzanPlayerService.onStateChanged = { state ->
            channel?.invokeMethod("stateChanged", state.toMap())
        }
    }

    private fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "replaceSchedule" -> onScheduleThread(result, "replace the Azan schedule") {
                val alarms = (call.argument<List<Map<String, Any?>>>("alarms") ?: emptyList())
                    .map(::alarmFrom)
                val labels = AzanLabels.fromMap(call.argument<Map<String, Any?>>("labels"))
                AzanSchedule.replace(context, alarms, labels)
            }
            "clearSchedule" -> onScheduleThread(result, "clear the Azan schedule") {
                val legacyIds = call.argument<List<Int>>("legacyIds") ?: emptyList()
                AzanSchedule.clear(context, legacyIds)
            }
            "rearm" -> onScheduleThread(result, "re-arm the Azan schedule") {
                AzanSchedule.rearm(context)
            }
            "play" -> {
                val prayerName = call.argument<String>("prayerName")
                val title = call.argument<String>("title")
                if (prayerName == null || title == null) {
                    result.error("invalid_arguments", "prayerName and title are required", null)
                    return
                }
                AzanLabels.fromMap(call.argument<Map<String, Any?>>("labels"))
                    ?.let { AzanSchedule.saveLabels(context, it) }
                AzanPlayerService.play(
                    context,
                    AzanPlayRequest(
                        prayerName = prayerName,
                        playingTitle = title,
                        pausedTitle = call.argument<String>("pausedTitle") ?: title,
                        customFilePath = call.argument<String>("customFilePath"),
                    ),
                    fromAlarm = false,
                )
                result.success(null)
            }
            "pause" -> {
                AzanPlayerService.pause()
                result.success(null)
            }
            "resume" -> {
                AzanPlayerService.resume()
                result.success(null)
            }
            "stop" -> {
                AzanPlayerService.stop()
                result.success(null)
            }
            "state" -> result.success(AzanPlayerService.state().toMap())
            else -> result.notImplemented()
        }
    }

    private fun onScheduleThread(
        result: MethodChannel.Result,
        what: String,
        work: () -> Unit,
    ) {
        scheduleExecutor.execute {
            try {
                work()
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                AzanLog.error(TAG, "Could not $what", e)
                mainHandler.post { result.error("azan_schedule", e.toString(), null) }
            }
        }
    }

    private fun alarmFrom(map: Map<String, Any?>) = AzanAlarm(
        id = (map["id"] as Number).toInt(),
        fireAtMillis = (map["fireAtMillis"] as Number).toLong(),
        prayerName = map["prayerName"] as String,
        playingTitle = map["title"] as String,
        pausedTitle = map["pausedTitle"] as? String ?: map["title"] as String,
        customFilePath = map["customFilePath"] as String?,
    )
}
