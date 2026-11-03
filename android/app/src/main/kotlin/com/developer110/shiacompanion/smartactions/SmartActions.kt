package com.developer110.shiacompanion.smartactions

import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import com.developer110.shia_companion.MainActivity
import com.developer110.shiacompanion.R
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import org.json.JSONArray

/**
 * The Android end of `lib/services/smart_actions_service.dart`: launcher
 * shortcuts and Google Assistant's App Actions, what Siri, Shortcuts and
 * Spotlight are on iOS (`ios/Runner/SmartActions`).
 *
 * Two directions:
 *
 * - **In**: a static shortcut (`res/xml/shortcuts.xml`), a shortcut this
 *   file made, or an App Action launches [MainActivity] with one of the
 *   `ACTION_*` actions below. [take] turns it into a call for Dart and holds
 *   it until Dart asks (`takeActions`). Dart asks rather than being told:
 *   audio_service keeps the engine - and Dart - alive across activities, so
 *   whether Dart is listening is not something this side can know. It is
 *   nudged with `actionsPending` in case it is.
 * - **Out**: Dart donates the playlists the reader plays and the duas they
 *   open, which become dynamic shortcuts (long-press the app icon, or type
 *   in the launcher's search), asks to pin a playlist to the home screen,
 *   and sends the catalog of playlists and duas, from which existing
 *   shortcuts are relabelled (a new app language) or retired (a deleted
 *   playlist).
 */
object SmartActions {
    private const val TAG = "SmartActions"
    private const val CHANNEL = "shia_companion/smart_actions"

    // Named in res/xml/shortcuts.xml; keep both in step.
    private const val ACTION_PREFIX = "com.developer110.shiacompanion.action."
    private const val ACTION_OPEN = ACTION_PREFIX + "OPEN"
    private const val ACTION_PLAY = ACTION_PREFIX + "PLAY"
    private const val ACTION_PLAY_PLAYLIST = ACTION_PREFIX + "PLAY_PLAYLIST"
    private const val ACTION_SEARCH = ACTION_PREFIX + "SEARCH"
    private const val ACTION_OPEN_LINK = ACTION_PREFIX + "OPEN_LINK"
    private const val EXTRA_NAME = "name"
    private const val EXTRA_QUERY = "query"
    private const val EXTRA_URL = "url"

    private const val KIND_PLAYLIST = "playlist"
    private const val KIND_ZIKR = "zikr"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val pending = mutableListOf<Map<String, Any?>>()
    private var channel: MethodChannel? = null

    fun attach(context: Context, messenger: BinaryMessenger) {
        val appContext = context.applicationContext
        channel = MethodChannel(messenger, CHANNEL).also {
            it.setMethodCallHandler { call, result -> handle(appContext, call, result) }
        }
        if (pending.isNotEmpty()) notifyDart()
    }

    /**
     * Queues what [intent] asks for, if it is one of ours. Not for an intent
     * the activity is being recreated with, or reopened with from Recents:
     * that one was carried out when it first came.
     */
    fun take(intent: Intent?, isRedelivery: Boolean) {
        if (intent == null || isRedelivery) return
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val request = requestFor(intent) ?: return
        // Carried out once: a configuration change re-reads getIntent().
        intent.action = Intent.ACTION_MAIN
        pending += request
        notifyDart()
    }

    private fun requestFor(intent: Intent): Map<String, Any?>? {
        fun text(key: String) = intent.getStringExtra(key)?.trim().orEmpty()
        return when (intent.action) {
            ACTION_OPEN -> call("openNamed", mapOf("name" to text(EXTRA_NAME)))
            ACTION_PLAY -> call("playNamed", mapOf("name" to text(EXTRA_NAME), "playlist" to false))
            ACTION_PLAY_PLAYLIST ->
                call("playNamed", mapOf("name" to text(EXTRA_NAME), "playlist" to true))
            ACTION_SEARCH -> call("search", mapOf("query" to text(EXTRA_QUERY)))
            ACTION_OPEN_LINK -> text(EXTRA_URL).takeIf { it.isNotEmpty() }
                ?.let { call("openLink", mapOf("url" to it)) }
            else -> null
        }
    }

    private fun call(method: String, arguments: Map<String, Any?>) =
        mapOf("method" to method, "arguments" to arguments)

    private fun notifyDart() {
        // Dropped harmlessly when Dart is not listening yet; it asks itself
        // once it starts.
        channel?.invokeMethod("actionsPending", null)
    }

    private fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ready" -> result.success(null)
            "takeActions" -> {
                result.success(pending.toList())
                pending.clear()
            }
            "updateCatalog" -> {
                val playlists = call.argument<String>("playlists")
                val zikrs = call.argument<String>("zikrs")
                scope.launch { refreshShortcuts(context, playlists, zikrs) }
                result.success(null)
            }
            "donateShortcut" -> {
                val shortcut = shortcutFrom(context, call)
                if (shortcut != null) {
                    scope.launch {
                        runCatching { ShortcutManagerCompat.pushDynamicShortcut(context, shortcut) }
                            .onFailure { Log.w(TAG, "Couldn't add a shortcut", it) }
                    }
                }
                result.success(null)
            }
            "canPinShortcuts" ->
                result.success(ShortcutManagerCompat.isRequestPinShortcutSupported(context))
            "pinShortcut" -> {
                val shortcut = shortcutFrom(context, call)
                if (shortcut == null) {
                    result.success(false)
                    return
                }
                val asked = runCatching {
                    ShortcutManagerCompat.requestPinShortcut(context, shortcut, null)
                }.onFailure { Log.w(TAG, "Couldn't pin a shortcut", it) }
                result.success(asked.getOrDefault(false))
            }
            else -> result.notImplemented()
        }
    }

    /** A shortcut that opens [link]; a playlist's link also plays it. */
    private fun shortcutFrom(context: Context, call: MethodCall): ShortcutInfoCompat? {
        val id = call.argument<String>("id")?.takeIf { it.isNotBlank() } ?: return null
        val label = call.argument<String>("label")?.takeIf { it.isNotBlank() } ?: return null
        val link = call.argument<String>("link")?.takeIf { it.isNotBlank() } ?: return null
        val icon = when (call.argument<String>("kind")) {
            KIND_PLAYLIST -> R.drawable.ic_shortcut_playlist
            else -> R.drawable.ic_shortcut_zikr
        }
        return ShortcutInfoCompat.Builder(context, id)
            .setShortLabel(label)
            .setLongLabel(label)
            .setIcon(IconCompat.createWithResource(context, icon))
            .setIntent(
                Intent(context, MainActivity::class.java)
                    .setAction(ACTION_OPEN_LINK)
                    .putExtra(EXTRA_URL, link)
            )
            // Lets the launcher's search and the system's suggestions keep it.
            .setLongLived(true)
            .build()
    }

    /**
     * Brings the shortcuts already made in line with the catalog: retitled
     * in the app's language as it is now, and the ones for a playlist since
     * deleted (or a dua since retired) taken away - or, pinned, disabled.
     */
    private fun refreshShortcuts(context: Context, playlists: String?, zikrs: String?) {
        val labels = HashMap<String, String>()
        playlists?.let { labels.putAll(catalogLabels(it, KIND_PLAYLIST)) }
        zikrs?.let { labels.putAll(catalogLabels(it, KIND_ZIKR)) }

        try {
            val existing = ShortcutManagerCompat.getShortcuts(
                context,
                ShortcutManagerCompat.FLAG_MATCH_DYNAMIC or ShortcutManagerCompat.FLAG_MATCH_PINNED
            )
            val gone = mutableListOf<String>()
            val retitled = mutableListOf<ShortcutInfoCompat>()
            for (shortcut in existing) {
                val kind = shortcut.id.substringBefore(':', "")
                // Only what this catalog covers: a playlist update says
                // nothing about duas, and a static shortcut is neither.
                if (kind == KIND_PLAYLIST && playlists == null) continue
                if (kind == KIND_ZIKR && zikrs == null) continue
                if (kind != KIND_PLAYLIST && kind != KIND_ZIKR) continue
                val label = labels[shortcut.id]
                when {
                    label == null -> gone += shortcut.id
                    label != shortcut.shortLabel.toString() -> retitled +=
                        ShortcutInfoCompat.Builder(shortcut)
                            .setShortLabel(label)
                            .setLongLabel(label)
                            .build()
                }
            }
            // Out of the launcher's list and search; a pinned one stays on
            // the home screen, greyed out.
            if (gone.isNotEmpty()) ShortcutManagerCompat.disableShortcuts(context, gone, null)
            if (retitled.isNotEmpty()) ShortcutManagerCompat.updateShortcuts(context, retitled)
        } catch (error: Exception) {
            Log.w(TAG, "Couldn't refresh shortcuts", error)
        }
    }

    /**
     * Shortcut id to label, from one half of the catalog Dart sends: the
     * title the reader sees (`subtitle`) when it has one, else `name`.
     */
    private fun catalogLabels(json: String, kind: String): Map<String, String> {
        val labels = HashMap<String, String>()
        try {
            val entries = JSONArray(json)
            for (i in 0 until entries.length()) {
                val entry = entries.optJSONObject(i) ?: continue
                val id = entry.optString("id").takeIf { it.isNotEmpty() } ?: continue
                val label = entry.optString("subtitle").takeIf { it.isNotBlank() }
                    ?: entry.optString("name").takeIf { it.isNotBlank() }
                    ?: continue
                labels["$kind:$id"] = label
            }
        } catch (error: Exception) {
            Log.w(TAG, "Couldn't read the $kind catalog", error)
        }
        return labels
    }
}
