package com.developer110.shiacompanion.wear.ui

import android.text.format.DateUtils
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import java.time.Instant
import java.time.ZoneId
import kotlinx.coroutines.delay

/**
 * Where the screens get the time from. Real time in the app; a fixed instant
 * in screenshot tests, so the same snapshot renders the same picture every run.
 */
fun interface WearClock {
    fun now(): Instant

    companion object {
        val System = WearClock { Instant.now() }
    }
}

val LocalWearClock = staticCompositionLocalOf { WearClock.System }
val LocalZone = staticCompositionLocalOf<ZoneId> { ZoneId.systemDefault() }

/**
 * The current instant, re-read every [periodMillis] and at [nextChange], so
 * a screen left open rolls over to the next prayer the moment it arrives
 * rather than sitting on a stale banner.
 */
@Composable
fun rememberTickingNow(clock: WearClock, nextChange: Instant?, periodMillis: Long = 30_000L): State<Instant> {
    val now = remember(clock) { mutableStateOf(clock.now()) }
    if (clock === WearClock.System) {
        LaunchedEffect(clock, nextChange) {
            while (true) {
                val current = clock.now()
                val untilChange = nextChange?.let { it.toEpochMilli() - current.toEpochMilli() + 500 }
                val wait = listOfNotNull(periodMillis, untilChange?.takeIf { it > 0 }).min()
                delay(wait)
                now.value = clock.now()
            }
        }
    }
    return now
}

/** "in 45 minutes", "5 minutes ago": the system's own wording, in the watch's language. */
fun relativeTime(target: Instant, now: Instant): String =
    DateUtils.getRelativeTimeSpanString(
        target.toEpochMilli(),
        now.toEpochMilli(),
        DateUtils.MINUTE_IN_MILLIS,
        DateUtils.FORMAT_ABBREV_RELATIVE,
    ).toString()
