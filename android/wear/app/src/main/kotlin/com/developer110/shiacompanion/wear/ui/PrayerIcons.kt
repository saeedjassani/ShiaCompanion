package com.developer110.shiacompanion.wear.ui

import androidx.annotation.DrawableRes
import com.developer110.shiacompanion.wear.R

/**
 * Words that identify each time in the names the phone sends, in every
 * language the phone app speaks (lib/l10n/app_*.arb's prayer* keys). The
 * phone sends names, not ids, so this is the only way to tell them apart.
 * Checked in order: Midnight's and Sunset's names must win before anything
 * a shorter word could match inside them.
 */
private val prayerNameWords: List<Pair<Int, List<String>>> = listOf(
    R.drawable.ic_prayer_midnight to listOf("midnight", "نصف شب", "نیمه", "منتصف", "મધ્યરાત્રિ"),
    R.drawable.ic_prayer_sunrise to listOf("sunrise", "طلوع", "الشروق", "સૂર્યોદય"),
    R.drawable.ic_prayer_sunset to listOf("sunset", "غروب", "સૂર્યાસ્ત"),
    R.drawable.ic_prayer_fajr to listOf("fajr", "فجر", "صبح", "ફજર"),
    R.drawable.ic_prayer_zuhr to listOf("zuhr", "dhuhr", "dhohr", "ظہر", "ظهر", "ઝોહર"),
    R.drawable.ic_prayer_asr to listOf("asr", "عصر", "અસર"),
    R.drawable.ic_prayer_maghrib to listOf("maghrib", "مغرب", "મગરિબ"),
    R.drawable.ic_prayer_isha to listOf("isha", "عشا", "ઇશા"),
)

/** The phone widgets' prayer glyph (copied from android/app/src/main/res) for a time's name. */
@DrawableRes
fun prayerIconRes(prayerName: String): Int {
    val name = prayerName.lowercase()
    return prayerNameWords.firstOrNull { (_, words) -> words.any { name.contains(it) } }?.first
        ?: R.drawable.ic_prayer_zuhr
}
