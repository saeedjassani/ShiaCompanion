package com.developer110.shiacompanion.wear.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.TransformingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberTransformingLazyColumnState
import androidx.wear.compose.material3.Button
import androidx.wear.compose.material3.ButtonDefaults
import androidx.wear.compose.material3.CircularProgressIndicator
import androidx.wear.compose.material3.FilledTonalButton
import androidx.wear.compose.material3.Icon
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import com.developer110.shiacompanion.wear.R
import com.developer110.shiacompanion.wear.data.SyncProblem
import com.developer110.shiacompanion.wear.data.WatchSnapshot
import java.time.Instant

/**
 * The app's root: the next prayer and the times after it, then a way into
 * the calendar and the counter. Both of those stay reachable when the phone
 * has never synced: the counter needs nothing from it, and the calendar
 * says what it is waiting for.
 */
@Composable
fun HomeScreen(
    snapshot: WatchSnapshot,
    isRequesting: Boolean,
    problem: SyncProblem?,
    onSync: () -> Unit,
    onOpenCalendar: () -> Unit,
    onOpenCounter: () -> Unit,
) {
    val clock = LocalWearClock.current
    val zone = LocalZone.current
    val initial = buildHomeState(snapshot, clock.now(), zone)
    val now by rememberTickingNow(clock, initial.nextChange)
    val state = buildHomeState(snapshot, now, zone)
    val listState = rememberTransformingLazyColumnState()

    ScreenScaffold(scrollState = listState) { contentPadding ->
        TransformingLazyColumn(state = listState, contentPadding = contentPadding) {
            when (state.mode) {
                HomeMode.LOADED -> {
                    if (state.location.isNotEmpty()) {
                        item { LocationHeader(state.location) }
                    }
                    state.next?.let { next -> item { NextPrayerBanner(next, now) } }
                    state.rows.forEach { row ->
                        row.dayBreak?.let { label -> item { DayBreak(label) } }
                        item { PrayerTimeRow(row) }
                    }
                }
                HomeMode.WAITING_FOR_PHONE -> item {
                    SyncPrompt(
                        title = stringResource(R.string.waiting_for_phone_title),
                        message = stringResource(R.string.waiting_for_phone_message),
                    )
                }
                HomeMode.NEEDS_LOCATION -> item {
                    SyncPrompt(
                        title = stringResource(R.string.location_needed_title),
                        message = stringResource(R.string.location_needed_message),
                    )
                }
            }

            if (state.mode != HomeMode.LOADED || problem != null) {
                item { SyncButton(isRequesting, onSync, primary = state.mode != HomeMode.LOADED) }
                problem?.let { item { ProblemText(it) } }
            }

            item { CalendarButton(state, now, onOpenCalendar) }
            item {
                FilledTonalButton(
                    onClick = onOpenCounter,
                    modifier = Modifier.fillMaxWidth(),
                    icon = { Icon(painterResource(R.drawable.ic_tasbeeh), contentDescription = null) },
                    label = { Text(stringResource(R.string.tasbeeh_counter), maxLines = 2) },
                )
            }

            if (state.mode == HomeMode.LOADED && problem == null) {
                item { SyncButton(isRequesting, onSync, primary = false) }
            }
            state.lastSync?.let { lastSync ->
                item {
                    Text(
                        text = stringResource(R.string.synced_ago, relativeTime(lastSync, now)),
                        style = MaterialTheme.typography.bodyExtraSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }
        }
    }
}

@Composable
private fun LocationHeader(location: String) {
    ListHeader {
        Icon(
            painterResource(R.drawable.ic_location),
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(14.dp),
        )
        Spacer(Modifier.width(4.dp))
        Text(
            location,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun NextPrayerBanner(next: com.developer110.shiacompanion.wear.data.PrayerScheduleEntry, now: Instant) {
    val zone = LocalZone.current
    val isToday = next.time.atZone(zone).toLocalDate() == now.atZone(zone).toLocalDate()
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceContainer, RoundedCornerShape(24.dp))
            .padding(vertical = 10.dp, horizontal = 12.dp),
    ) {
        Text(
            text = if (isToday) stringResource(R.string.up_next) else stringResource(R.string.up_next_on, next.dateLabel),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                painterResource(prayerIconRes(next.name)),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(18.dp),
            )
            Spacer(Modifier.width(6.dp))
            Text(
                next.name,
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.primary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        Text(
            next.displayTime,
            style = MaterialTheme.typography.displaySmall.copy(textDirection = TextDirection.Content),
            fontWeight = FontWeight.Bold,
            maxLines = 1,
        )
        Text(
            relativeTime(next.time, now),
            style = MaterialTheme.typography.labelSmall.copy(textDirection = TextDirection.Content),
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/** Names the day the rows below belong to: a rule with a label, not a row of its own. */
@Composable
private fun DayBreak(label: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 12.dp, end = 12.dp, top = 6.dp),
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
        )
        Spacer(Modifier.width(6.dp))
        Box(
            Modifier
                .weight(1f)
                .height(1.dp)
                .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.35f))
        )
    }
}

@Composable
private fun PrayerTimeRow(row: PrayerRow) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceContainerLow, RoundedCornerShape(50))
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(24.dp)
                .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.2f), CircleShape),
        ) {
            Icon(
                painterResource(prayerIconRes(row.entry.name)),
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(14.dp),
            )
        }
        Text(
            row.entry.name,
            style = MaterialTheme.typography.bodyMedium,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Text(
            row.entry.displayTime,
            style = MaterialTheme.typography.bodyMedium.copy(textDirection = TextDirection.Content),
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
        )
    }
}

@Composable
private fun SyncPrompt(title: String, message: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
    ) {
        Icon(
            painterResource(R.drawable.ic_phone),
            contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.size(24.dp),
        )
        Spacer(Modifier.height(4.dp))
        Text(title, style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
        Spacer(Modifier.height(2.dp))
        Text(
            message,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun SyncButton(isRequesting: Boolean, onSync: () -> Unit, primary: Boolean) {
    val label = stringResource(if (primary) R.string.sync_now else R.string.refresh)
    val icon: @Composable () -> Unit = {
        if (isRequesting) {
            CircularProgressIndicator(modifier = Modifier.size(ButtonDefaults.IconSize))
        } else {
            Icon(painterResource(R.drawable.ic_refresh), contentDescription = null)
        }
    }
    if (primary) {
        Button(
            onClick = onSync,
            enabled = !isRequesting,
            modifier = Modifier.fillMaxWidth(),
            icon = { icon() },
            label = { Text(label) },
        )
    } else {
        FilledTonalButton(
            onClick = onSync,
            enabled = !isRequesting,
            modifier = Modifier.fillMaxWidth(),
            icon = { icon() },
            label = { Text(label) },
        )
    }
}

@Composable
private fun ProblemText(problem: SyncProblem) {
    Text(
        text = stringResource(
            when (problem) {
                SyncProblem.PHONE_APP_MISSING -> R.string.phone_app_missing
                SyncProblem.UNREACHABLE -> R.string.phone_unreachable
            }
        ),
        style = MaterialTheme.typography.bodyExtraSmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
    )
}

/**
 * Today's hijri date, and the way into the calendar. Before the phone has
 * sent a calendar it is just the word, so the screen is still reachable.
 */
@Composable
private fun CalendarButton(state: HomeState, now: Instant, onClick: () -> Unit) {
    val day = state.hijriDay
    val subtitle = when {
        day == null -> null
        day.event.isNotEmpty() -> day.event
        state.nextEvent != null -> stringResource(R.string.calendar_next_event, state.nextEvent.short) +
            " · " + whenText(state.nextEvent.start, now)
        else -> stringResource(R.string.upcoming_events)
    }
    FilledTonalButton(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        icon = { Icon(painterResource(R.drawable.ic_calendar), contentDescription = null) },
        label = {
            Text(
                day?.dateLine ?: stringResource(R.string.calendar),
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        },
        secondaryLabel = subtitle?.let {
            {
                Text(
                    it,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    color = if (day?.event?.isNotEmpty() == true) eventColor(day.color) else Color.Unspecified,
                    fontSize = 12.sp,
                )
            }
        },
    )
}
