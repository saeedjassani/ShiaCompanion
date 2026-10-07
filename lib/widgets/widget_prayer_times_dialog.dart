import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/analytics_service.dart';
import '../services/home_screen_widget_service.dart';
import '../services/prayer_preferences_sync_service.dart';
import '../theme/shia_colors.dart';
import '../utils/widget_prayer_time_selection.dart';
import 'choice_sheet.dart';
import 'outline_icon.dart';
import 'page_chrome.dart';
import 'prayer_glyph.dart';

/// The Prayer times shown picker, shared by Settings and the home page card
/// so the setting can be reached from the thing it changes as well as from
/// the settings list. A sheet of the times with a tick on each one shown;
/// what is ticked when it closes is saved, and the home screen widgets
/// republished.
///
/// Returns true when the selection changed, so callers can rebuild.
Future<bool> showWidgetPrayerTimesDialog(BuildContext context) async {
  final selected = selectedWidgetPrayerTimes().map((time) => time.id).toSet();
  final before = Set<String>.of(selected);

  await showRevampSheet<void>(
    context,
    title: context.l10n.settingsPrayerTimesShown,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) {
        final colors = ShiaColors.of(context);
        final atMinimum = selected.length <= minWidgetPrayerTimes;
        final atMaximum = selected.length >= maxWidgetPrayerTimes;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                context.l10n.widgetPrayerTimesHelp(
                    minWidgetPrayerTimes, maxWidgetPrayerTimes),
                style: ShiaText.secondary.copyWith(color: colors.textMuted),
              ),
            ),
            const SizedBox(height: 10),
            CardList(
              children: [
                for (final (i, time) in widgetPrayerTimes.indexed)
                  Builder(builder: (context) {
                    final shown = selected.contains(time.id);
                    final enabled = shown ? !atMinimum : !atMaximum;
                    return MergeSemantics(
                      child: Semantics(
                        checked: shown,
                        enabled: enabled,
                        child: Opacity(
                          opacity: enabled ? 1 : 0.5,
                          child: CardListRow(
                            first: i == 0,
                            last: i == widgetPrayerTimes.length - 1,
                            leading: PrayerGlyph(
                              name: time.name,
                              size: 24,
                              color: colors.accent,
                            ),
                            title: Text(
                                localizedPrayerName(time.name, context.l10n)),
                            trailing: SizedBox.square(
                              dimension: 44,
                              child: Center(child: _Tick(selected: shown)),
                            ),
                            onTap: enabled
                                ? () => setSheetState(() {
                                      if (shown) {
                                        selected.remove(time.id);
                                      } else {
                                        selected.add(time.id);
                                      }
                                    })
                                : null,
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ],
        );
      },
    ),
  );

  // Closing without having changed anything is not a modification, and
  // counting it would make the metric a measure of how often the sheet is
  // opened.
  if (setEquals(before, selected)) return false;

  final ids = [
    for (final time in widgetPrayerTimes)
      if (selected.contains(time.id)) time.id,
  ];
  await saveWidgetPrayerTimes(ids);
  unawaited(PrayerPreferencesSyncService.instance.pushWidgetPrayerTimes());
  await HomeScreenWidgetService.instance.publishAll();
  unawaited(AnalyticsService.prayerTimesSelectionChanged(ids));
  return true;
}

/// A round tick: filled in the accent when on, an empty ring when off.
class _Tick extends StatelessWidget {
  const _Tick({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = ShiaColors.of(context);
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.accent : null,
        border: selected
            ? null
            : Border.all(
                color: Color.lerp(colors.line, colors.chevron, 0.35)!,
                width: 2),
      ),
      child: selected
          ? OutlineIcon(OutlineGlyph.check,
              size: 15, color: colors.onAccent, strokeWidth: 3)
          : null,
    );
  }
}
