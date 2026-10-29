package com.developer110.shiacompanion.wear.ui

import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.input.rotary.onRotaryScrollEvent
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material3.AlertDialog
import androidx.wear.compose.material3.AlertDialogDefaults
import androidx.wear.compose.material3.CircularProgressIndicator
import androidx.wear.compose.material3.FilledTonalIconButton
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import com.developer110.shiacompanion.wear.R
import com.developer110.shiacompanion.wear.counter.CountFeedback
import com.developer110.shiacompanion.wear.counter.CounterState

/**
 * Rotary input arrives as scroll pixels, not detents: this is how far the
 * crown or bezel has to travel for one count. A first guess, to be tuned on
 * a real watch (docs/WEAR_OS.md, "Still to check on a device").
 */
private const val ROTARY_PIXELS_PER_COUNT = 48f

/**
 * The tasbeeh counter. The whole screen is the button, so a count lands
 * wherever the thumb falls without looking; turning the crown or bezel counts
 * too. The ring around the edge fills towards the target and starts over on
 * each lap.
 */
@Composable
fun CounterScreen(
    state: CounterState,
    onAdjust: (Int) -> CountFeedback,
    onReset: () -> CountFeedback,
    onCycleTarget: () -> Unit,
) {
    val view = LocalView.current
    val focusRequester = remember { FocusRequester() }
    var rotaryPixels by remember { mutableFloatStateOf(0f) }
    var confirmingReset by remember { mutableStateOf(false) }
    val addOne = stringResource(R.string.add_one)

    fun adjust(by: Int) = feedback(view, onAdjust(by))

    ScreenScaffold(timeText = {}) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .fillMaxSize()
                .onRotaryScrollEvent { event ->
                    rotaryPixels += event.verticalScrollPixels
                    val steps = (rotaryPixels / ROTARY_PIXELS_PER_COUNT).toInt()
                    if (steps != 0) {
                        rotaryPixels -= steps * ROTARY_PIXELS_PER_COUNT
                        adjust(steps)
                    }
                    true
                }
                .focusRequester(focusRequester)
                .focusable()
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClickLabel = addOne,
                ) { adjust(1) }
                .semantics {
                    contentDescription = addOne
                    stateDescription = state.count.toString()
                },
        ) {
            CircularProgressIndicator(
                progress = { if (state.target > 0) state.progress else 0f },
                modifier = Modifier.fillMaxSize().padding(2.dp),
                strokeWidth = 6.dp,
            )
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                TargetChip(state, onCycleTarget)
                Text(
                    state.count.toString(),
                    fontSize = 52.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                )
                Text(
                    stringResource(R.string.tasbeeh_hint),
                    style = MaterialTheme.typography.bodyExtraSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
                Spacer(Modifier.height(8.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    FilledTonalIconButton(
                        onClick = { adjust(-1) },
                        enabled = state.count > 0,
                    ) {
                        Icon(painterResource(R.drawable.ic_minus), stringResource(R.string.minus_one))
                    }
                    FilledTonalIconButton(
                        onClick = { confirmingReset = true },
                        enabled = state.count > 0,
                    ) {
                        Icon(painterResource(R.drawable.ic_reset), stringResource(R.string.reset))
                    }
                }
            }
        }
    }

    AlertDialog(
        visible = confirmingReset,
        onDismissRequest = { confirmingReset = false },
        title = { Text(stringResource(R.string.reset_question), textAlign = TextAlign.Center) },
        confirmButton = {
            AlertDialogDefaults.ConfirmButton(onClick = {
                confirmingReset = false
                feedback(view, onReset())
            })
        },
    )

    // The rotary events go to whatever holds focus, so the counter claims it
    // on arrival and again when the reset dialog hands it back.
    LaunchedEffect(confirmingReset) {
        if (!confirmingReset) runCatching { focusRequester.requestFocus() }
    }
}

@Composable
private fun TargetChip(state: CounterState, onCycleTarget: () -> Unit) {
    val label = if (state.target == 0) {
        stringResource(R.string.no_target)
    } else {
        // Isolated left to right, or an RTL language reads "21 / 33" as "33 / 21".
        "\u2066" + stringResource(R.string.target_progress, state.lapCount, state.target) + "\u2069"
    }
    val changeTarget = stringResource(R.string.change_target)
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .background(MaterialTheme.colorScheme.surfaceContainer, CircleShape)
            .clickable(onClickLabel = changeTarget) { onCycleTarget() }
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) {
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
        if (state.target > 0 && state.lap > 1) {
            Spacer(Modifier.width(4.dp))
            Text(
                stringResource(R.string.lap, state.lap),
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/**
 * A light tick per count, a stronger confirm on each milestone - the buzz
 * someone counting without looking is waiting for.
 */
private fun feedback(view: View, feedback: CountFeedback) {
    val constant = when (feedback) {
        CountFeedback.NONE -> return
        CountFeedback.TICK, CountFeedback.TICK_DOWN -> HapticFeedbackConstants.CLOCK_TICK
        CountFeedback.MILESTONE -> HapticFeedbackConstants.CONFIRM
        CountFeedback.RESET -> HapticFeedbackConstants.LONG_PRESS
    }
    view.performHapticFeedback(constant)
}
