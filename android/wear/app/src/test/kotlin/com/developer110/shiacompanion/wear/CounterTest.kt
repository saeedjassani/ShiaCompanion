package com.developer110.shiacompanion.wear

import androidx.test.core.app.ApplicationProvider
import com.developer110.shiacompanion.wear.counter.CountFeedback
import com.developer110.shiacompanion.wear.counter.CounterState
import com.developer110.shiacompanion.wear.counter.CounterStore
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner

@RunWith(RobolectricTestRunner::class)
class CounterTest {
    @Test
    fun `progress reads full on a milestone and laps after it`() {
        assertEquals(0f, CounterState(0, 33).progress)
        assertEquals(1f, CounterState(33, 33).progress)
        assertEquals(1f / 33, CounterState(34, 33).progress)
        assertEquals(1, CounterState(33, 33).lap)
        assertEquals(2, CounterState(34, 33).lap)
        assertEquals(33, CounterState(33, 33).lapCount)
        assertEquals(1, CounterState(34, 33).lapCount)
        assertEquals(0f, CounterState(10, 0).progress)
    }

    @Test
    fun `counting feels a milestone, even when a crown flick jumps past it`() {
        val store = CounterStore.get(ApplicationProvider.getApplicationContext())
        store.reset()
        while (store.state.value.target != 33) store.cycleTarget()
        assertEquals(CountFeedback.TICK, store.adjust(30))
        assertEquals(CountFeedback.MILESTONE, store.adjust(5))
        assertEquals(35, store.state.value.count)
        assertEquals(CountFeedback.TICK_DOWN, store.adjust(-1))
        assertEquals(CountFeedback.RESET, store.reset())
        assertEquals(CountFeedback.NONE, store.adjust(-1))
        store.adjust(CounterState.MAX_COUNT + 10)
        assertEquals(CounterState.MAX_COUNT, store.state.value.count)
        store.reset()
    }
}
