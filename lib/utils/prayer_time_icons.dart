import 'package:flutter/material.dart';

// Each prayer/time gets its own glyph so the list is scannable at a glance;
// none of these should be reused for another entry (see prayer_time_icons_test.dart).
IconData prayerIconFor(String prayerName) {
  final name = prayerName.toLowerCase();
  if (name.contains('fajr')) return Icons.wb_twilight;
  if (name.contains('sunrise')) return Icons.wb_sunny;
  if (name.contains('zuhr') ||
      name.contains('dhuhr') ||
      name.contains('dhohr')) {
    // Not light_mode: that constant renders identical to wb_sunny (used
    // above for Sunrise) — MD3 kept the same glyph under the new name.
    return Icons.flare;
  }
  if (name.contains('asr')) return Icons.brightness_5;
  if (name.contains('sunset')) return Icons.wb_twilight_outlined;
  // Not a crescent-moon icon (dark_mode/nightlight_round): Isha and
  // Midnight already own that family, so Maghrib stays in the
  // brightness-dial family instead — a shaded disc, not a moon.
  if (name.contains('maghrib')) return Icons.brightness_4;
  if (name.contains('isha')) return Icons.nights_stay;
  if (name.contains('midnight')) return Icons.bedtime;
  return Icons.mosque;
}
