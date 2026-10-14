package com.developer110.shiacompanion.azan

import org.junit.Assert.assertEquals
import org.junit.Test

class AzanScheduleRulesTest {
    private val zuhr = AzanAlarm(
        id = 301,
        fireAtMillis = 1_000_000_000L,
        prayerName = "Zuhr",
        playingTitle = "Zuhr Azan is playing",
        pausedTitle = "Zuhr Azan is paused",
        customFilePath = null,
    )
    private val maghrib = zuhr.copy(id = 601, fireAtMillis = zuhr.fireAtMillis + 6 * 3_600_000L)

    @Test
    fun `plays an alarm delivered on time`() {
        assertEquals(AzanDelivery.PLAY, AzanScheduleRules.decide(listOf(zuhr), 301, zuhr.fireAtMillis, zuhr.fireAtMillis))
    }

    @Test
    fun `plays an alarm a little late, up to the limit`() {
        val now = zuhr.fireAtMillis + AzanScheduleRules.LATE_LIMIT_MILLIS
        assertEquals(AzanDelivery.PLAY, AzanScheduleRules.decide(listOf(zuhr), 301, zuhr.fireAtMillis, now))
    }

    @Test
    fun `never plays an alarm later than the limit`() {
        val now = zuhr.fireAtMillis + AzanScheduleRules.LATE_LIMIT_MILLIS + 1
        assertEquals(AzanDelivery.LATE, AzanScheduleRules.decide(listOf(zuhr), 301, zuhr.fireAtMillis, now))
    }

    @Test
    fun `never plays an alarm that is no longer scheduled`() {
        assertEquals(AzanDelivery.UNSCHEDULED, AzanScheduleRules.decide(listOf(maghrib), 301, zuhr.fireAtMillis, zuhr.fireAtMillis))
        assertEquals(AzanDelivery.UNSCHEDULED, AzanScheduleRules.decide(emptyList(), 301, zuhr.fireAtMillis, zuhr.fireAtMillis))
    }

    @Test
    fun `never plays an old delivery of an id since rescheduled to another time`() {
        // Ids are reused day to day; the stored time is what the schedule vouches for.
        val moved = zuhr.copy(fireAtMillis = zuhr.fireAtMillis + 60_000L)
        assertEquals(AzanDelivery.UNSCHEDULED, AzanScheduleRules.decide(listOf(moved), 301, zuhr.fireAtMillis, zuhr.fireAtMillis))
        assertEquals(AzanDelivery.PLAY, AzanScheduleRules.decide(listOf(moved), 301, moved.fireAtMillis, moved.fireAtMillis))
    }

    @Test
    fun `never plays an alarm delivered well before its time, after the clock moved back`() {
        val now = zuhr.fireAtMillis - AzanScheduleRules.EARLY_LIMIT_MILLIS - 1
        assertEquals(AzanDelivery.EARLY, AzanScheduleRules.decide(listOf(zuhr), 301, zuhr.fireAtMillis, now))
    }

    @Test
    fun `plays an alarm delivered a few seconds early`() {
        val now = zuhr.fireAtMillis - 15_000L
        assertEquals(AzanDelivery.PLAY, AzanScheduleRules.decide(listOf(zuhr), 301, zuhr.fireAtMillis, now))
    }

    @Test
    fun `re-arming keeps upcoming and slightly late alarms and drops stale ones`() {
        val stale = zuhr.copy(id = 101, fireAtMillis = zuhr.fireAtMillis - AzanScheduleRules.LATE_LIMIT_MILLIS - 1)
        val slightlyLate = zuhr.copy(id = 102, fireAtMillis = zuhr.fireAtMillis - 60_000L)
        val armable = AzanScheduleRules.armable(listOf(stale, slightlyLate, zuhr, maghrib), zuhr.fireAtMillis)
        assertEquals(listOf(slightlyLate, zuhr, maghrib), armable)
    }

    @Test
    fun `the schedule survives a round trip through storage, custom file included`() {
        val custom = maghrib.copy(customFilePath = "/data/user/0/app/files/my_azan.mp3")
        val stored = AzanScheduleRules.serialize(listOf(zuhr, custom))
        assertEquals(listOf(zuhr, custom), AzanScheduleRules.parse(stored))
    }

    @Test
    fun `nothing stored reads as an empty schedule`() {
        assertEquals(emptyList<AzanAlarm>(), AzanScheduleRules.parse(null))
        assertEquals(emptyList<AzanAlarm>(), AzanScheduleRules.parse(""))
    }
}
