package com.developer110.shiacompanion.wear.counter

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import com.developer110.shiacompanion.wear.data.SurfaceUpdater
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** A tasbeeh count and the target it laps at (0 for none). */
data class CounterState(val count: Int = 0, val target: Int = 0) {
    /**
     * How far into the current lap the count is. Reads full (rather than
     * empty) exactly on a milestone, then starts over on the next count.
     */
    val progress: Float
        get() {
            if (target <= 0 || count <= 0) return 0f
            val remainder = count % target
            return if (remainder == 0) 1f else remainder.toFloat() / target
        }

    /** 1 while below the first target, then 2, 3... so long sessions stay readable. */
    val lap: Int get() = if (target <= 0 || count <= 0) 1 else (count - 1) / target + 1

    /** The count within the current lap, as shown beside the target. */
    val lapCount: Int
        get() = if (target <= 0) count else if (count > 0 && count % target == 0) target else count % target

    companion object {
        /** Guards against a runaway crown spin producing a nonsensical count. */
        const val MAX_COUNT = 99_999

        /** 0 means no target; the rest are the milestones the phone app beeps at. */
        val TARGET_OPTIONS = listOf(0, 33, 34, 100, 1000)
    }
}

/** What a count change should feel like. */
enum class CountFeedback { NONE, TICK, TICK_DOWN, MILESTONE, RESET }

/**
 * The watch's tasbeeh counter. Local to the watch, like the Apple Watch
 * app's: the phone's counter lives in Flutter's preferences, with nothing to
 * sync it against. Every change is written straight through, so the count
 * survives the app being killed mid-dhikr.
 */
class CounterStore private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val prefs: SharedPreferences =
        appContext.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)

    private val _state = MutableStateFlow(
        CounterState(
            count = prefs.getInt(KEY_COUNT, 0).coerceIn(0, CounterState.MAX_COUNT),
            target = prefs.getInt(KEY_TARGET, 0).takeIf { it in CounterState.TARGET_OPTIONS } ?: 0,
        )
    )
    val state: StateFlow<CounterState> = _state.asStateFlow()

    fun adjust(by: Int): CountFeedback {
        val before = _state.value
        val updated = (before.count + by).coerceIn(0, CounterState.MAX_COUNT)
        if (by == 0 || updated == before.count) return CountFeedback.NONE
        // Compares laps rather than testing `updated % target`, so a crown
        // flick that jumps several counts at once still lands the milestone.
        val crossedTarget = before.target > 0 && updated > before.count &&
            updated / before.target > before.count / before.target
        save(before.copy(count = updated))
        return when {
            crossedTarget -> CountFeedback.MILESTONE
            by > 0 -> CountFeedback.TICK
            else -> CountFeedback.TICK_DOWN
        }
    }

    fun reset(): CountFeedback {
        if (_state.value.count == 0) return CountFeedback.NONE
        save(_state.value.copy(count = 0))
        return CountFeedback.RESET
    }

    fun cycleTarget() {
        val options = CounterState.TARGET_OPTIONS
        val index = options.indexOf(_state.value.target).coerceAtLeast(0)
        save(_state.value.copy(target = options[(index + 1) % options.size]))
    }

    private fun save(state: CounterState) {
        _state.value = state
        prefs.edit {
            putInt(KEY_COUNT, state.count)
            putInt(KEY_TARGET, state.target)
        }
        SurfaceUpdater.requestCounter(appContext)
    }

    companion object {
        private const val PREFERENCES_NAME = "shia_companion_wear_counter"
        private const val KEY_COUNT = "count"
        private const val KEY_TARGET = "target"

        @Volatile
        private var instance: CounterStore? = null

        fun get(context: Context): CounterStore =
            instance ?: synchronized(this) {
                instance ?: CounterStore(context).also { instance = it }
            }
    }
}
