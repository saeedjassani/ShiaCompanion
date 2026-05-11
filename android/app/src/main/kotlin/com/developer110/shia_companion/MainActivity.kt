package com.developer110.shia_companion

import android.content.ContentValues
import android.net.Uri
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Locale

class MainActivity: FlutterActivity() {
    private val notificationAudioChannel = "shia_companion/notification_audio"

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
