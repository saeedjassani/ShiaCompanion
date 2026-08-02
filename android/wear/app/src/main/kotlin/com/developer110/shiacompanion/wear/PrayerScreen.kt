package com.developer110.shiacompanion.wear

import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.ScalingLazyListScope
import androidx.wear.compose.foundation.lazy.rememberScalingLazyListState
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.Colors
import androidx.wear.compose.material.CompactChip
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.PositionIndicator
import androidx.wear.compose.material.Scaffold
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.TimeText
import androidx.wear.compose.material.Vignette
import androidx.wear.compose.material.VignettePosition
import androidx.compose.ui.graphics.Color
import kotlinx.coroutines.delay

/** Matches the home screen widgets, so the two read as one app. */
private val WearPalette = Colors(
    primary = Color(0xFFFFD879),
    onPrimary = Color(0xFF241B17),
    secondary = Color(0xFFE4C7B3),
    onSecondary = Color(0xFF241B17),
    background = Color(0xFF000000),
    onBackground = Color(0xFFFFF3E7),
    surface = Color(0xFF241B17),
    onSurface = Color(0xFFFFF3E7),
)

private const val TICK_MILLIS = 30_000L

enum class SyncStatus {
    /** The phone has never sent a snapshot. */
    WAITING_FOR_PHONE,

    /** Synced, but the phone app has no location saved yet. */
    NEEDS_LOCATION,
    LOADED,
}

data class PrayerUiState(
    val status: SyncStatus,
    val location: String,
    val nextPrayer: PrayerScheduleEntry?,
    val prayers: List<PrayerEntry>,
    val lastSyncedAtMillis: Long?,
)

private fun PrayerDataStore.uiState(nowMillis: Long): PrayerUiState {
    val status = when {
        !hasSyncedData -> SyncStatus.WAITING_FOR_PHONE
        !hasPrayerTimes -> SyncStatus.NEEDS_LOCATION
        else -> SyncStatus.LOADED
    }

    return PrayerUiState(
        status = status,
        location = location,
        nextPrayer = nextPrayer(nowMillis),
        prayers = if (status == SyncStatus.LOADED) dailyPrayers(nowMillis) else emptyList(),
        lastSyncedAtMillis = lastSyncedAtMillis,
    )
}

@Composable
fun PrayerApp() {
    val context = LocalContext.current
    val store = remember { PrayerDataStore.get(context) }

    val revision by PhoneSyncManager.revision.collectAsState()
    val isRequesting by PhoneSyncManager.isRequesting.collectAsState()
    val lastError by PhoneSyncManager.lastError.collectAsState()

    // Re-derives the "next" prayer as one passes, so an open app never sits on a stale
    // banner, and keeps the countdown honest.
    var nowMillis by remember { mutableStateOf(System.currentTimeMillis()) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(TICK_MILLIS)
            nowMillis = System.currentTimeMillis()
        }
    }

    val state = remember(revision, nowMillis) { store.uiState(nowMillis) }
    val listState = rememberScalingLazyListState()

    MaterialTheme(colors = WearPalette) {
        Scaffold(
            timeText = { TimeText() },
            vignette = { Vignette(vignettePosition = VignettePosition.TopAndBottom) },
            positionIndicator = { PositionIndicator(scalingLazyListState = listState) },
        ) {
            ScalingLazyColumn(
                modifier = Modifier.fillMaxSize(),
                state = listState,
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                when (state.status) {
                    SyncStatus.LOADED -> loadedContent(
                        state = state,
                        nowMillis = nowMillis,
                        isRequesting = isRequesting,
                        onRefresh = { PhoneSyncManager.requestSnapshot(context) },
                    )

                    SyncStatus.WAITING_FOR_PHONE -> item {
                        SyncPrompt(
                            title = stringResource(R.string.waiting_for_phone_title),
                            message = stringResource(R.string.waiting_for_phone_message),
                            isRequesting = isRequesting,
                            errorMessage = lastError,
                            onRetry = { PhoneSyncManager.requestSnapshot(context) },
                        )
                    }

                    SyncStatus.NEEDS_LOCATION -> item {
                        SyncPrompt(
                            title = stringResource(R.string.needs_location_title),
                            message = stringResource(R.string.needs_location_message),
                            isRequesting = isRequesting,
                            errorMessage = lastError,
                            onRetry = { PhoneSyncManager.requestSnapshot(context) },
                        )
                    }
                }
            }
        }
    }
}

private fun ScalingLazyListScope.loadedContent(
    state: PrayerUiState,
    nowMillis: Long,
    isRequesting: Boolean,
    onRefresh: () -> Unit,
) {
    if (state.location.isNotEmpty()) {
        item { LocationHeader(state.location) }
    }

    state.nextPrayer?.let { next ->
        item { NextPrayerCard(next = next, nowMillis = nowMillis) }
    }

    if (state.prayers.isNotEmpty()) {
        item { Spacer(Modifier.height(4.dp)) }
        items(state.prayers.size) { index ->
            PrayerRow(state.prayers[index])
        }
    }

    item {
        CompactChip(
            onClick = onRefresh,
            modifier = Modifier.padding(top = 8.dp),
            label = {
                Text(
                    text = if (isRequesting) {
                        stringResource(R.string.syncing)
                    } else {
                        stringResource(R.string.refresh)
                    }
                )
            },
        )
    }

    state.lastSyncedAtMillis?.let { syncedAt ->
        item {
            Text(
                text = stringResource(R.string.synced_relative, relativeTime(syncedAt)),
                style = MaterialTheme.typography.caption3,
                color = MaterialTheme.colors.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
            )
        }
    }
}

@Composable
private fun LocationHeader(location: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            painter = painterResource(R.drawable.ic_location),
            contentDescription = stringResource(R.string.location),
            tint = MaterialTheme.colors.primary,
            modifier = Modifier.size(12.dp),
        )
        Spacer(Modifier.width(4.dp))
        Text(
            text = location,
            style = MaterialTheme.typography.caption2,
            color = MaterialTheme.colors.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun NextPrayerCard(next: PrayerScheduleEntry, nowMillis: Long) {
    val heading = if (next.dateLabel.isBlank() || next.dateLabel == "Today") {
        stringResource(R.string.next_prayer)
    } else {
        stringResource(R.string.next_prayer_on, next.dateLabel)
    }
    val remaining = remainingTime(next.epochMillis, nowMillis)

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(MaterialTheme.colors.primary.copy(alpha = 0.15f))
            .padding(vertical = 10.dp, horizontal = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = heading,
            style = MaterialTheme.typography.caption3,
            color = MaterialTheme.colors.onSurfaceVariant,
            maxLines = 1,
        )
        Text(
            text = next.name,
            style = MaterialTheme.typography.title3,
            color = MaterialTheme.colors.primary,
            maxLines = 1,
        )
        Text(
            text = next.time,
            style = MaterialTheme.typography.display3,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
        )
        if (remaining.isNotEmpty()) {
            Text(
                text = stringResource(R.string.in_time, remaining),
                style = MaterialTheme.typography.caption3,
                color = MaterialTheme.colors.onSurfaceVariant,
                maxLines = 1,
            )
        }
        if (next.secondaryName.isNotBlank() && next.secondaryTime.isNotBlank()) {
            Text(
                text = "${next.secondaryName}: ${next.secondaryTime}",
                style = MaterialTheme.typography.caption3,
                color = MaterialTheme.colors.onSurfaceVariant,
                maxLines = 1,
            )
        }
    }
}

@Composable
private fun PrayerRow(prayer: PrayerEntry) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colors.surface)
            .padding(vertical = 8.dp, horizontal = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(22.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colors.primary.copy(alpha = 0.2f)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                painter = painterResource(prayerIconRes(prayer.name)),
                contentDescription = null,
                tint = MaterialTheme.colors.primary,
                modifier = Modifier.size(13.dp),
            )
        }
        Spacer(Modifier.width(8.dp))
        Text(
            text = prayer.name,
            style = MaterialTheme.typography.body2,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            text = prayer.time,
            style = MaterialTheme.typography.body2,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
        )
    }
}

@Composable
private fun SyncPrompt(
    title: String,
    message: String,
    isRequesting: Boolean,
    errorMessage: String?,
    onRetry: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(
            painter = painterResource(R.drawable.ic_phone_sync),
            contentDescription = null,
            tint = MaterialTheme.colors.primary,
            modifier = Modifier.size(22.dp),
        )
        Text(
            text = title,
            style = MaterialTheme.typography.title3,
            textAlign = TextAlign.Center,
        )
        Text(
            text = message,
            style = MaterialTheme.typography.caption2,
            color = MaterialTheme.colors.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        if (isRequesting) {
            CircularProgressIndicator(modifier = Modifier.size(24.dp))
        } else {
            CompactChip(
                onClick = onRetry,
                label = { Text(stringResource(R.string.sync_now)) },
            )
        }
        if (errorMessage != null && !isRequesting) {
            Text(
                text = errorMessage,
                style = MaterialTheme.typography.caption3,
                color = MaterialTheme.colors.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

private fun relativeTime(millis: Long): CharSequence =
    DateUtils.getRelativeTimeSpanString(
        millis,
        System.currentTimeMillis(),
        DateUtils.MINUTE_IN_MILLIS,
    )
