package com.developer110.shiacompanion.wear

import com.developer110.shiacompanion.wear.ui.prayerIconRes
import org.junit.Assert.assertEquals
import org.junit.Test

/** The phone sends names in its own language; each still finds its glyph. */
class PrayerIconsTest {
    @Test
    fun `names in every app language find their glyph`() {
        val cases = mapOf(
            R.drawable.ic_prayer_fajr to listOf("Fajr", "فجر", "صبح", "الفجر", "ફજર"),
            R.drawable.ic_prayer_sunrise to listOf("Sunrise", "طلوع آفتاب", "الشروق", "સૂર્યોદય"),
            R.drawable.ic_prayer_zuhr to listOf("Zuhr", "ظہر", "ظهر", "الظهر", "ઝોહર"),
            R.drawable.ic_prayer_asr to listOf("Asr", "عصر", "العصر", "અસર"),
            R.drawable.ic_prayer_sunset to listOf("Sunset", "غروب آفتاب", "الغروب", "સૂર્યાસ્ત"),
            R.drawable.ic_prayer_maghrib to listOf("Maghrib", "مغرب", "المغرب", "મગરિબ"),
            R.drawable.ic_prayer_isha to listOf("Isha", "عشاء", "عشا", "العشاء", "ઇશા"),
            R.drawable.ic_prayer_midnight to listOf("Midnight", "نصف شب", "نیمه‌شب", "منتصف الليل", "મધ્યરાત્રિ"),
        )
        cases.forEach { (icon, names) ->
            names.forEach { assertEquals("$it", icon, prayerIconRes(it)) }
        }
    }
}
