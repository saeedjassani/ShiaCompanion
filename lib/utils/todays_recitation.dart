import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/utils/lunar_date_matcher.dart';
import 'package:shia_companion/utils/night_window.dart';

/// Builds today's recitation list purely from each zikr's `day` patterns in
/// `assets/zikr.json` (see [matchesLunarDatePattern]) - occasions, whole
/// months, weekdays ("*-*-5") and every-day recitations ("*-*") alike.
///
/// Only canonical zikr entries carry a `day`; an alias ("<uid>|<target>")
/// never does, so each recitation appears exactly once without any
/// de-duplication here.
///
/// Items are ordered most specific occasion first (a date or night, then a
/// month, then a weekday, then every day - see [lunarPatternSpecificity]),
/// and by each zikr's order value within that.
List<UidTitleData> buildTodaysRecitationItems({DateTime? now}) {
  final today = now ?? DateTime.now();
  final adjustedHijriDate = HijriCalendar.fromDate(
    today.add(Duration(days: hijriDate)),
  );

  final nightDate = resolveNightAdjustedHijriDate(
    now: today,
    prayerTime: getPrayerTimeObject(),
    latitude: lat,
    longitude: long,
    hijriDateOffsetDays: hijriDate,
  );

  final matches = matchTodaysZikrs(
    itemMetadata,
    currentDate: adjustedHijriDate,
    nightDate: nightDate,
    // Recurring weekday patterns (e.g. "*-*-5" for Friday) should follow the
    // real calendar day, not the moon-sighting-adjusted Hijri date: the
    // `adjust_hijri_date` setting shifts which lunar date today is, but it
    // has no bearing on which civil weekday today actually is.
    weekdayAnchor: today,
  );

  final recitations = <UidTitleData>[];
  matches.forEach((uid, _) {
    final title = items[uid];
    if (title is String && title.trim().isNotEmpty) {
      recitations.add(UidTitleData(uid, title));
    }
  });

  recitations.sort((a, b) {
    final bySpecificity = matches[a.uid]!.compareTo(matches[b.uid]!);
    if (bySpecificity != 0) return bySpecificity;

    final byOrder =
        getItemOrderValue(a.uid).compareTo(getItemOrderValue(b.uid));
    if (byOrder != 0) return byOrder;

    final byId = a.getId().compareTo(b.getId());
    if (byId != 0) return byId;

    return a.uid.compareTo(b.uid);
  });

  return recitations;
}
