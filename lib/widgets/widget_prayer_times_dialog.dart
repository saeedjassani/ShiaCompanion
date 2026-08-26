import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
import '../services/home_screen_widget_service.dart';
import '../utils/prayer_time_icons.dart';
import '../utils/widget_prayer_time_selection.dart';

/// The "Prayer Times Shown" picker, shared by Settings and the home page card
/// so the setting can be reached from the thing it changes as well as from the
/// settings list. Saves and republishes the home screen widgets itself.
///
/// Returns true when the selection was saved, so callers can rebuild.
Future<bool> showWidgetPrayerTimesDialog(BuildContext context) async {
  final selected = selectedWidgetPrayerTimes().map((time) => time.id).toSet();
  final before = Set<String>.of(selected);

  final saved = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          final atMinimum = selected.length <= minWidgetPrayerTimes;
          final atMaximum = selected.length >= maxWidgetPrayerTimes;

          return AlertDialog(
            title: const Text("Prayer Times Shown"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Text(
                      "Pick $minWidgetPrayerTimes to $maxWidgetPrayerTimes "
                      "times. Sunrise, Sunset and Midnight are the deadlines "
                      "a prayer has to be offered before.",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  for (final time in widgetPrayerTimes)
                    CheckboxListTile(
                      dense: true,
                      secondary: Icon(prayerIconFor(time.name)),
                      title: Text(time.name),
                      value: selected.contains(time.id),
                      onChanged:
                          (selected.contains(time.id) ? atMinimum : atMaximum)
                              ? null
                              : (bool? value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      selected.add(time.id);
                                    } else {
                                      selected.remove(time.id);
                                    }
                                  });
                                },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text("Save"),
              ),
            ],
          );
        },
      );
    },
  );

  if (saved != true) return false;

  final ids = selected.toList();
  await saveWidgetPrayerTimes(ids);
  await HomeScreenWidgetService.instance.publishAll();
  // Saving without having changed anything is not a modification, and counting
  // it would make the metric a measure of how often the dialog is opened.
  if (!setEquals(before, selected)) {
    unawaited(AnalyticsService.prayerTimesSelectionChanged(ids));
  }
  return true;
}
