package com.developer110.shiacompanion.wear.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material3.ColorScheme
import androidx.wear.compose.material3.MaterialTheme

/**
 * The phone's prayer card, carried to the watch: gold on warm brown, on the
 * black every watch face sits on (docs/DESIGN_SPEC.md). Wear OS is always
 * dark, so there is no light scheme.
 */
object WearColors {
    val Gold = Color(0xFFE4C27A)
    val OnGold = Color(0xFF2A1E16)
    val Brown = Color(0xFF3A2A1F)
    val BrownHigh = Color(0xFF4A3A2E)
    val Text = Color(0xFFF2EBE2)
    val TextMuted = Color(0xFFBFB0A2)
    /** events.json's joy, as the phone's dark calendar draws it. */
    val Joy = Color(0xFF7FBF95)
    /** events.json's mourning: grey, as black would vanish on the watch. */
    val Mourning = Color(0xFFC5C8CE)
}

private val colorScheme = ColorScheme(
    primary = WearColors.Gold,
    primaryDim = WearColors.Gold,
    primaryContainer = WearColors.BrownHigh,
    onPrimary = WearColors.OnGold,
    onPrimaryContainer = WearColors.Text,
    secondary = WearColors.TextMuted,
    onSecondary = WearColors.OnGold,
    surfaceContainerLow = Color(0xFF1E1712),
    surfaceContainer = WearColors.Brown,
    surfaceContainerHigh = WearColors.BrownHigh,
    onSurface = WearColors.Text,
    onSurfaceVariant = WearColors.TextMuted,
    background = Color.Black,
    onBackground = WearColors.Text,
)

@Composable
fun ShiaCompanionTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = colorScheme, content = content)
}

/** events.json's colour code: 0 mourning, 1 joy, anything else none. */
fun eventColor(code: Int): Color = when (code) {
    0 -> WearColors.Mourning
    1 -> WearColors.Joy
    else -> WearColors.Gold
}
