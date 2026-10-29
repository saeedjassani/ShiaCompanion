package com.developer110.shiacompanion.wear.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.TransformingLazyColumn
import androidx.wear.compose.foundation.lazy.rememberTransformingLazyColumnState
import androidx.wear.compose.material3.ListHeader
import androidx.wear.compose.material3.MaterialTheme
import androidx.wear.compose.material3.ScreenScaffold
import androidx.wear.compose.material3.Text
import com.developer110.shiacompanion.wear.R
import com.developer110.shiacompanion.wear.data.IslamicEvent
import com.developer110.shiacompanion.wear.data.WatchSnapshot
import com.developer110.shiacompanion.wear.data.calendarDaysAway
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/** How many upcoming events the calendar lists. */
const val UPCOMING_EVENT_LIMIT = 12

/**
 * Today's hijri date and event, and the events after it. Each event leads
 * with its name; the line under it says what happened, when, and its hijri
 * date.
 */
@Composable
fun CalendarScreen(snapshot: WatchSnapshot) {
    val clock = LocalWearClock.current
    val zone = LocalZone.current
    val now by rememberTickingNow(clock, snapshot.transitionsAfter(clock.now()).firstOrNull())
    val day = snapshot.hijriDay(now)
    val events = snapshot.upcomingEvents(now, zone, UPCOMING_EVENT_LIMIT)
    val listState = rememberTransformingLazyColumnState()

    ScreenScaffold(scrollState = listState) { contentPadding ->
        TransformingLazyColumn(state = listState, contentPadding = contentPadding) {
            item {
                ListHeader {
                    Text(stringResource(R.string.islamic_calendar), style = MaterialTheme.typography.titleSmall)
                }
            }
            if (day != null) {
                item {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(
                                day.day.toString(),
                                fontSize = 34.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary,
                            )
                            Spacer(Modifier.width(6.dp))
                            Column {
                                Text(day.month, style = MaterialTheme.typography.titleSmall, maxLines = 1)
                                Text(
                                    stringResource(R.string.hijri_year, day.year) + " · " +
                                        now.atZone(zone).toLocalDate()
                                            .format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)),
                                    style = MaterialTheme.typography.bodyExtraSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1,
                                )
                            }
                        }
                        if (day.event.isNotEmpty()) {
                            Spacer(Modifier.size(4.dp))
                            EventLine(day.event, day.color, centered = true)
                            if (day.kind.isNotEmpty()) {
                                Text(
                                    stringResource(R.string.event_kind_when, stringResource(R.string.today), day.kind),
                                    style = MaterialTheme.typography.bodyExtraSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
            }
            if (events.isEmpty()) {
                item {
                    Text(
                        stringResource(R.string.calendar_not_synced),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
                    )
                }
            } else {
                item {
                    ListHeader {
                        Text(
                            stringResource(R.string.upcoming),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                }
                events.forEach { event -> item { UpcomingEventRow(event, now) } }
            }
        }
    }
}

/**
 * An event's name, marked with its colour: a dot beside a row's title, or -
 * centred under today's date, where a wrapped title would strand the dot -
 * the title itself in that colour.
 */
@Composable
private fun EventLine(title: String, color: Int, centered: Boolean = false) {
    if (centered) {
        Text(
            title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = eventColor(color),
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
        return
    }
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Box(
            Modifier
                .size(6.dp)
                .background(eventColor(color), CircleShape)
        )
        Spacer(Modifier.width(6.dp))
        Text(title, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun UpcomingEventRow(event: IslamicEvent, now: Instant) {
    val time = whenText(event.start, now)
    val meta = if (event.kind.isEmpty()) time else stringResource(R.string.event_kind_when, event.kind, time)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surfaceContainerLow, RoundedCornerShape(18.dp))
            .padding(horizontal = 14.dp, vertical = 8.dp),
    ) {
        EventLine(event.title, event.color)
        Text(
            "$meta · ${event.day} ${event.monthShort}",
            style = MaterialTheme.typography.bodyExtraSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            modifier = Modifier.padding(start = 12.dp),
        )
    }
}

/** "Today", "Tomorrow", "In 4 days", in the watch's language. */
@Composable
fun whenText(start: Instant, now: Instant): String {
    val days = calendarDaysAway(start, now, LocalZone.current).toInt()
    return when {
        days <= 0 -> stringResource(R.string.today)
        days == 1 -> stringResource(R.string.tomorrow)
        else -> pluralStringResource(R.plurals.in_days, days, days)
    }
}
