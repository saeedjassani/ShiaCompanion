package com.developer110.shia_companion

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.glance.appwidget.updateAll
import com.developer110.shiacompanion.widgets.DailyPrayerTimesWidget
import com.developer110.shiacompanion.widgets.FavoritesWidget
import com.developer110.shiacompanion.widgets.scheduleNextPrayerWidgetRefresh
import com.developer110.shiacompanion.widgets.scheduleNextRecitationWidgetRefresh
import com.developer110.shiacompanion.widgets.TodaysRecitationWidget
import com.developer110.shiacompanion.widgets.UpcomingPrayerWidget
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

// AudioServiceActivity (from just_audio_background) instead of plain
// FlutterActivity: it reuses the engine audio_service keeps alive in its
// foreground service, so zikr audio survives the activity being destroyed
// (app swiped away) while playback continues in the notification.
class MainActivity: AudioServiceActivity() {
    private val notificationAudioChannel = "shia_companion/notification_audio"
    private val homeWidgetsChannel = "shia_companion/home_widgets"
    private val proximitySensorChannel = "shia_companion/proximity_sensor"
    private val proximitySensorEventsChannel =
        "shia_companion/proximity_sensor_events"
    private val widgetPreferencesName = "shia_companion_widgets"
    private val widgetUrlExtra = "com.developer110.shiacompanion.WIDGET_URL"
    private val mainScope = CoroutineScope(Dispatchers.Main)
    private var homeWidgetsMethodChannel: MethodChannel? = null
    private var pendingWidgetUrl: String? = null
    private var sensorManager: SensorManager? = null
    private var proximitySensor: Sensor? = null
    private var proximityEventSink: EventChannel.EventSink? = null
    private var lastProximityState: Boolean? = null
    private val proximityListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            val sensor = proximitySensor ?: return
            val isNear = event.values.firstOrNull()?.let { it < sensor.maximumRange }
                ?: return
            if (lastProximityState == isNear) return

            lastProximityState = isNear
            proximityEventSink?.success(isNear)
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingWidgetUrl = consumeWidgetUrl(intent)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val widgetUrl = consumeWidgetUrl(intent)
        if (widgetUrl.isNullOrBlank()) return

        val channel = homeWidgetsMethodChannel
        if (channel == null) {
            pendingWidgetUrl = widgetUrl
        } else {
            channel.invokeMethod("openWidgetUrl", widgetUrl)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationAudioChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "registerNotificationSound" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error(
                            "missing_path",
                            "Audio file path is required.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        val uri = registerNotificationSound(path)
                        if (uri == null) {
                            result.error(
                                "file_not_found",
                                "Audio file could not be read.",
                                null
                            )
                        } else {
                            result.success(uri.toString())
                        }
                    } catch (error: Exception) {
                        result.error(
                            "registration_failed",
                            error.localizedMessage,
                            null
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        homeWidgetsMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            homeWidgetsChannel
        )
        homeWidgetsMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeWidgetUrl" -> {
                    result.success(pendingWidgetUrl)
                    pendingWidgetUrl = null
                }
                "saveWidgetData" -> {
                    val values = call.arguments as? Map<*, *>
                    if (values == null) {
                        result.error(
                            "invalid_arguments",
                            "Widget data must be a map of string keys and values.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val editor = applicationContext
                        .getSharedPreferences(widgetPreferencesName, MODE_PRIVATE)
                        .edit()
                    values.forEach { (key, value) ->
                        if (key is String && value != null) {
                            editor.putString(key, value.toString())
                        }
                    }
                    if (editor.commit()) {
                        result.success(null)
                    } else {
                        result.error(
                            "save_failed",
                            "Widget data could not be saved.",
                            null
                        )
                    }
                }
                "refreshWidgets" -> {
                    mainScope.launch {
                        try {
                            FavoritesWidget().updateAll(applicationContext)
                            TodaysRecitationWidget().updateAll(applicationContext)
                            DailyPrayerTimesWidget().updateAll(applicationContext)
                            UpcomingPrayerWidget().updateAll(applicationContext)
                            scheduleNextPrayerWidgetRefresh(applicationContext)
                            scheduleNextRecitationWidgetRefresh(applicationContext)
                            result.success(null)
                        } catch (error: Exception) {
                            result.error(
                                "refresh_failed",
                                error.localizedMessage,
                                null
                            )
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        configureProximitySensorChannels(flutterEngine)
    }

    private fun configureProximitySensorChannels(flutterEngine: FlutterEngine) {
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        proximitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_PROXIMITY)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            proximitySensorChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(proximitySensor != null)
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            proximitySensorEventsChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val manager = sensorManager
                val sensor = proximitySensor
                if (manager == null || sensor == null) {
                    events.error(
                        "sensor_unavailable",
                        "This device does not have a proximity sensor.",
                        null
                    )
                    return
                }

                proximityEventSink = events
                lastProximityState = null
                val registered = manager.registerListener(
                    proximityListener,
                    sensor,
                    SensorManager.SENSOR_DELAY_NORMAL
                )
                if (!registered) {
                    proximityEventSink = null
                    events.error(
                        "sensor_registration_failed",
                        "The proximity sensor could not be started.",
                        null
                    )
                }
            }

            override fun onCancel(arguments: Any?) {
                sensorManager?.unregisterListener(proximityListener)
                proximityEventSink = null
                lastProximityState = null
            }
        })
    }

    override fun onDestroy() {
        sensorManager?.unregisterListener(proximityListener)
        proximityEventSink = null
        super.onDestroy()
    }

    private fun consumeWidgetUrl(intent: Intent?): String? {
        val widgetUrl = intent
            ?.getStringExtra(widgetUrlExtra)
            ?.takeIf { it.isNotBlank() }
        intent?.removeExtra(widgetUrlExtra)
        return widgetUrl
    }

    private fun registerNotificationSound(path: String): Uri? {
        val sourceFile = File(path)
        if (!sourceFile.exists() || !sourceFile.canRead()) return null

        val extension = sourceFile.extension.ifBlank { "mp3" }
        val mimeType = MimeTypeMap.getSingleton()
            .getMimeTypeFromExtension(extension.lowercase(Locale.US))
            ?: "audio/mpeg"
        val safeBaseName = sourceFile.nameWithoutExtension
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .ifBlank { "custom_azan" }
        val displayName =
            "shia_companion_${safeBaseName}_${sourceFile.length()}_${sourceFile.lastModified()}.$extension"
        val relativePath =
            "${Environment.DIRECTORY_NOTIFICATIONS}${File.separator}Shia Companion"

        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
            put(MediaStore.Audio.Media.RELATIVE_PATH, relativePath)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, true)
            put(MediaStore.Audio.Media.IS_ALARM, true)
            put(MediaStore.Audio.Media.IS_MUSIC, false)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }

        val resolver = applicationContext.contentResolver
        val uri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
            ?: return null

        try {
            val outputStream = resolver.openOutputStream(uri)
                ?: throw IllegalStateException("Unable to open notification sound output stream.")
            outputStream.use { stream ->
                sourceFile.inputStream().use { inputStream ->
                    inputStream.copyTo(stream)
                }
            }

            val publishValues = ContentValues().apply {
                put(MediaStore.Audio.Media.IS_PENDING, 0)
            }
            resolver.update(uri, publishValues, null, null)
            return uri
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }
}
