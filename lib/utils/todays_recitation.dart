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
  // Weekdays come from the civil date and lunar dates from the
  // moon-sighting-adjusted one - see LunarDay.
  final today = now ?? DateTime.now();
  final day = LunarDay(today, hijriOffsetDays: hijriDate);
  final night = resolveNightLunarDay(
    now: today,
    prayerTime: getPrayerTimeObject(),
    latitude: lat,
    longitude: long,
    hijriDateOffsetDays: hijriDate,
  );

  final matches = matchTodaysZikrs(itemMetadata, day: day, night: night);

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
