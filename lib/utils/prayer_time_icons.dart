import 'package:flutter/material.dart';

IconData prayerIconFor(String prayerName) {
  final name = prayerName.toLowerCase();
  if (name.contains('fajr')) return Icons.wb_twilight;
  if (name.contains('sunrise')) return Icons.light_mode;
  if (name.contains('zuhr') ||
      name.contains('dhuhr') ||
      name.contains('dhohr')) {
    return Icons.wb_sunny;
  }
  if (name.contains('asr')) return Icons.brightness_5;
  if (name.contains('sunset')) return Icons.wb_twilight_outlined;
  if (name.contains('maghrib')) return Icons.wb_twilight;
  if (name.contains('isha')) return Icons.nights_stay;
  if (name.contains('midnight')) return Icons.bedtime;
  return Icons.mosque;
}
