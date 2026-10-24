package com.developer110.shiacompanion.wear

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.hasScrollToIndexAction
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performScrollToIndex
import androidx.wear.compose.material3.AppScaffold
import com.developer110.shiacompanion.wear.counter.CountFeedback
import com.developer110.shiacompanion.wear.counter.CounterState
import com.developer110.shiacompanion.wear.data.SyncProblem
import com.developer110.shiacompanion.wear.data.WatchSnapshot
import com.developer110.shiacompanion.wear.ui.CalendarScreen
import com.developer110.shiacompanion.wear.ui.CounterScreen
import com.developer110.shiacompanion.wear.ui.HomeScreen
import com.developer110.shiacompanion.wear.ui.LocalWearClock
import com.developer110.shiacompanion.wear.ui.LocalZone
import com.developer110.shiacompanion.wear.ui.ShiaCompanionTheme
import com.developer110.shiacompanion.wear.ui.WearClock
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.shadows.ShadowLog
import org.robolectric.RuntimeEnvironment

/**
 * Renders every screen on a small and a large round watch, in English and in
 * Urdu (right to left), so a reviewer without a watch can see each one. CI
 * uploads them as the "wear-screenshots" artifact.
 *
 * These record rather than compare: they fail only if a screen crashes.
 * Run `./gradlew :app:recordRoborazziDebug` and look in
 * app/build/outputs/roborazzi/.
 */
@RunWith(ParameterizedRobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35])
class ScreenshotTest(private val device: Device) {
    enum class Device(val qualifiers: String) {
        SMALL_ROUND("w192dp-h192dp-small-notlong-round-watch-xhdpi-keyshidden-nonav"),
        LARGE_ROUND("w227dp-h227dp-small-notlong-round-watch-xhdpi-keyshidden-nonav"),
        LARGE_ROUND_URDU("ur-w227dp-h227dp-small-notlong-round-watch-xhdpi-keyshidden-nonav"),
    }

    companion object {
        @JvmStatic
        @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
        fun devices() = Device.entries.map { arrayOf<Any>(it) }
    }

    @get:Rule
    val compose = createComposeRule()

    private val urdu get() = device == Device.LARGE_ROUND_URDU
    private val snapshot get() = SampleSnapshot.snapshot(if (urdu) SampleSnapshot.urdu else SampleSnapshot.Names())

    /**
     * Captures [content] as it first appears and, when [scrollTo] is given,
     * again scrolled to that item - a list's lower rows are otherwise never
     * seen in a screenshot of a round screen.
     */
    private fun capture(name: String, scrollTo: Int? = null, content: @Composable () -> Unit) {
        RuntimeEnvironment.setQualifiers(device.qualifiers)
        ShadowLog.stream = null
        compose.setContent {
            CompositionLocalProvider(
                LocalWearClock provides WearClock { SampleSnapshot.now },
                LocalZone provides SampleSnapshot.zone,
            ) {
                ShiaCompanionTheme {
                    // The watch's own round mask, which Robolectric does not draw.
                    Box(Modifier.fillMaxSize().background(Color.Black).clip(CircleShape)) {
                        AppScaffold(timeText = {}) { content() }
                    }
                }
            }
        }
        compose.onRoot().captureRoboImage("build/outputs/roborazzi/${device.name.lowercase()}/$name.png")
        if (scrollTo != null) {
            compose.onNode(hasScrollToIndexAction()).performScrollToIndex(scrollTo)
            compose.onRoot().captureRoboImage("build/outputs/roborazzi/${device.name.lowercase()}/${name}_scrolled.png")
        }
    }

    @Test
    fun home() = capture("home", scrollTo = 5) {
        HomeScreen(snapshot, isRequesting = false, problem = null, onSync = {}, onOpenCalendar = {}, onOpenCounter = {})
    }

    @Test
    fun homeWaitingForPhone() = capture("home_waiting_for_phone") {
        HomeScreen(
            WatchSnapshot.EMPTY,
            isRequesting = false,
            problem = SyncProblem.UNREACHABLE,
            onSync = {},
            onOpenCalendar = {},
            onOpenCounter = {},
        )
    }

    @Test
    fun homeNeedsLocation() = capture("home_needs_location") {
        HomeScreen(SampleSnapshot.noLocation, isRequesting = true, problem = null, onSync = {}, onOpenCalendar = {}, onOpenCounter = {})
    }

    @Test
    fun calendar() = capture("calendar", scrollTo = 4) { CalendarScreen(snapshot) }

    @Test
    fun counter() = capture("counter") {
        CounterScreen(CounterState(count = 21, target = 33), { CountFeedback.TICK }, { CountFeedback.RESET }, {})
    }

    @Test
    fun counterNoTarget() = capture("counter_no_target") {
        CounterScreen(CounterState(count = 1250, target = 0), { CountFeedback.TICK }, { CountFeedback.RESET }, {})
    }
}
