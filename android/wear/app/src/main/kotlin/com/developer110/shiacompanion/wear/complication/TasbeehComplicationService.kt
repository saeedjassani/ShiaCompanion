package com.developer110.shiacompanion.wear.complication

import android.content.Context
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.RangedValueComplicationData
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService
import com.developer110.shiacompanion.wear.R
import com.developer110.shiacompanion.wear.counter.CounterState
import com.developer110.shiacompanion.wear.counter.CounterStore
import com.developer110.shiacompanion.wear.ui.Routes

/**
 * The tasbeeh count on the watch face, with the lap's progress as a ring
 * where the face has room for one. A tap opens the counter.
 */
class TasbeehComplicationService : SuspendingComplicationDataSourceService() {
    override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData? =
        data(this, request.complicationType, CounterStore.get(this).state.value)

    override fun getPreviewData(type: ComplicationType): ComplicationData? =
        data(this, type, CounterState(count = 21, target = 33), preview = true)

    private fun data(context: Context, type: ComplicationType, state: CounterState, preview: Boolean = false): ComplicationData? {
        val description = plain("${context.getString(R.string.tasbeeh)} ${state.count}")
        val tap = if (preview) null else openRoute(context, Routes.COUNTER)
        val icon = monochrome(context, R.drawable.ic_tasbeeh)
        return when (type) {
            ComplicationType.SHORT_TEXT ->
                ShortTextComplicationData.Builder(plain(state.count.toString()), description)
                    .setMonochromaticImage(icon)
                    .setTapAction(tap)
                    .build()
            ComplicationType.RANGED_VALUE -> {
                // With no target there is no lap to fill, so the ring stays empty.
                val max = if (state.target > 0) state.target.toFloat() else 1f
                val value = if (state.target > 0) state.progress * state.target else 0f
                RangedValueComplicationData.Builder(value, 0f, max, description)
                    .setText(plain(state.count.toString()))
                    .setMonochromaticImage(icon)
                    .setTapAction(tap)
                    .build()
            }
            else -> null
        }
    }
}
