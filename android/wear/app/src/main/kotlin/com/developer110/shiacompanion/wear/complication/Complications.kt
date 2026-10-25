package com.developer110.shiacompanion.wear.complication

import android.app.PendingIntent
import android.content.Context
import android.graphics.drawable.Icon
import androidx.annotation.DrawableRes
import androidx.wear.watchface.complications.data.ComplicationText
import androidx.wear.watchface.complications.data.MonochromaticImage
import androidx.wear.watchface.complications.data.PlainComplicationText
import com.developer110.shiacompanion.wear.MainActivity

internal fun plain(text: CharSequence): ComplicationText = PlainComplicationText.Builder(text).build()

internal fun monochrome(context: Context, @DrawableRes res: Int): MonochromaticImage =
    MonochromaticImage.Builder(Icon.createWithResource(context, res)).build()

/**
 * A tap on a complication opens the app on the screen the complication was
 * showing. One request code per route, so the three never overwrite each
 * other's PendingIntent.
 */
internal fun openRoute(context: Context, route: String): PendingIntent =
    PendingIntent.getActivity(
        context,
        route.hashCode(),
        MainActivity.intent(context, route),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
