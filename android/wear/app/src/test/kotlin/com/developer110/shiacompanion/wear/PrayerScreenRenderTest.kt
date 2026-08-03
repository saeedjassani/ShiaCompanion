package com.developer110.shiacompanion.wear

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onAllNodesWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

private const val NOW = 1_700_000_000_000L

private const val SMALL_ROUND = "w192dp-h192dp-small-notlong-round-watch-xhdpi-keyshidden-nonav"
private const val LARGE_ROUND = "w227dp-h227dp-small-notlong-round-watch-xhdpi-keyshidden-nonav"
private const val SQUARE = "w192dp-h192dp-small-notlong-notround-watch-xhdpi-keyshidden-nonav"

/**
 * Renders the watch screen in every state the phone can leave it in, on the watch shapes
 * we ship to, and fails on anything raised while laying it out.
 *
 * This is the Wear half of what `test/ui/page_render_test.dart` does for the Flutter app:
 * a bad constraint, a null during composition or a crash in the state derivation surfaces
 * here in seconds, with no golden files to maintain. It renders [PrayerScreen] rather than
 * [PrayerApp] so no store, data layer or clock has to be stood up — and so the screen's
 * 30 second tick, which never completes, cannot hang the test.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
class PrayerScreenRenderTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    @Config(qualifiers = SMALL_ROUND)
    fun `renders prayer times on a small round watch`() {
        render(loadedState())

        composeTestRule.onNodeWithText("Karbala").assertIsDisplayed()
        assertRendered("Maghrib")
        assertRendered("7:30 pm")
    }

    @Test
    @Config(qualifiers = LARGE_ROUND)
    fun `renders prayer times on a large round watch`() {
        render(loadedState())

        composeTestRule.onNodeWithText("Karbala").assertIsDisplayed()
        assertRendered("Maghrib")
    }

    @Test
    @Config(qualifiers = SQUARE)
    fun `renders prayer times on a square watch`() {
        render(loadedState())

        composeTestRule.onNodeWithText("Karbala").assertIsDisplayed()
        assertRendered("Maghrib")
    }

    @Test
    @Config(qualifiers = SMALL_ROUND)
    fun `renders the day label when the next prayer is not today`() {
        render(
            loadedState().copy(
                nextPrayer = scheduleEntry(dateLabel = "Tomorrow"),
            )
        )

        assertRendered("Next Prayer · Tomorrow")
    }

    @Test
    @Config(qualifiers = SMALL_ROUND)
    fun `renders the prompt when the phone has never synced`() {
        render(
            PrayerUiState(
                status = SyncStatus.WAITING_FOR_PHONE,
                location = "",
                nextPrayer = null,
                prayers = emptyList(),
                lastSyncedAtMillis = null,
            )
        )

        composeTestRule.onNodeWithText("Waiting for phone").assertIsDisplayed()
        assertRendered("Sync now")
    }

    @Test
    @Config(qualifiers = SMALL_ROUND)
    fun `renders the prompt when the phone has no location`() {
        render(
            PrayerUiState(
                status = SyncStatus.NEEDS_LOCATION,
                location = "Location needed",
                nextPrayer = null,
                prayers = emptyList(),
                lastSyncedAtMillis = NOW - 60_000L,
            )
        )

        composeTestRule.onNodeWithText("Location needed").assertIsDisplayed()
    }

    @Test
    @Config(qualifiers = SMALL_ROUND)
    fun `renders the failure the last sync reported`() {
        render(
            state = PrayerUiState(
                status = SyncStatus.WAITING_FOR_PHONE,
                location = "",
                nextPrayer = null,
                prayers = emptyList(),
                lastSyncedAtMillis = null,
            ),
            errorMessage = "Phone not connected.",
        )

        assertRendered("Phone not connected.")
    }

    @Test
    @Config(qualifiers = SMALL_ROUND)
    fun `renders a sync in flight without a retry chip`() {
        render(
            state = PrayerUiState(
                status = SyncStatus.WAITING_FOR_PHONE,
                location = "",
                nextPrayer = null,
                prayers = emptyList(),
                lastSyncedAtMillis = null,
            ),
            isRequesting = true,
        )

        assertTrue(
            "the retry chip should give way to the progress indicator",
            composeTestRule.onAllNodesWithText("Sync now").fetchSemanticsNodes().isEmpty(),
        )
    }

    private fun render(
        state: PrayerUiState,
        isRequesting: Boolean = false,
        errorMessage: String? = null,
    ) {
        // Wear's TimeText keeps a clock ticking, and a test clock left on auto never goes
        // idle against it. Drive frames by hand instead.
        composeTestRule.mainClock.autoAdvance = false
        composeTestRule.setContent {
            PrayerScreen(
                state = state,
                nowMillis = NOW,
                isRequesting = isRequesting,
                errorMessage = errorMessage,
                onRefresh = {},
            )
        }
        composeTestRule.mainClock.advanceTimeByFrame()
    }

    /**
     * Asserts the text was composed. Items further down the list may sit off screen, so
     * existence — not visibility — is what can be asserted for all of them.
     */
    private fun assertRendered(text: String) {
        assertTrue(
            "expected \"$text\" on screen",
            composeTestRule.onAllNodesWithText(text, substring = true)
                .fetchSemanticsNodes()
                .isNotEmpty(),
        )
    }

    private fun loadedState() = PrayerUiState(
        status = SyncStatus.LOADED,
        location = "Karbala",
        nextPrayer = scheduleEntry(),
        prayers = listOf(
            PrayerEntry("Fajr", "4:30 am"),
            PrayerEntry("Zuhr", "12:15 pm"),
            PrayerEntry("Asr", "4:00 pm"),
            PrayerEntry("Maghrib", "7:30 pm"),
            PrayerEntry("Isha", "8:45 pm"),
        ),
        lastSyncedAtMillis = NOW - 5 * 60_000L,
    )

    private fun scheduleEntry(dateLabel: String = "Today") = PrayerScheduleEntry(
        epochMillis = NOW + 60 * 60_000L,
        name = "Maghrib",
        time = "7:30 pm",
        dateLabel = dateLabel,
        secondaryName = "Midnight",
        secondaryTime = "11:50 pm",
    )
}
