import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/utils/lunar_date_matcher.dart';
import 'package:shia_companion/utils/night_window.dart';

/// Today as the `day` patterns read it: the civil day with its Hijri date,
/// and the night open right now (Maghrib to Fajr), if one is.
///
/// Weekdays come from the civil date and lunar dates from the
/// moon-sighting-adjusted one - see LunarDay.
({LunarDay day, LunarDay? night}) todaysLunarDays({DateTime? now}) {
  final today = now ?? DateTime.now();
  return (
    day: LunarDay(today, hijriOffsetDays: hijriDate),
    night: resolveNightLunarDay(
      now: today,
      prayerTime: getPrayerTimeObject(),
      latitude: lat,
      longitude: long,
      hijriDateOffsetDays: hijriDate,
    ),
  );
}

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
List<UidTitleData> buildTodaysRecitationItems({DateTime? now}) => [
      for (final group in buildTodaysRecitationGroups(now: now)) ...group.items,
    ];

/// What a group of today's recitations is for.
enum TodaysRecitationKind {
  /// Tonight's date: the Night of Qadr, the 15th of Shaban's night.
  night,

  /// Today's date, or a once-a-year weekday ("the first Thursday of Rajab").
  date,

  /// The current month, all of it or some of its weekdays.
  month,

  /// Today's weekday.
  weekday,

  /// Every day.
  everyDay,
}

/// Today's recitations of one [kind], as Today's Recitations heads them.
class TodaysRecitationGroup {
  const TodaysRecitationGroup(this.kind, this.items);

  final TodaysRecitationKind kind;
  final List<UidTitleData> items;
}

/// Today's recitations in groups, most specific first (see
/// [buildTodaysRecitationItems]): tonight's and today's dates, the month,
/// the weekday, every day. A zikr sits in the group of its most specific
/// pattern that matches, so Dua Kumayl on the 15th of Shaban's night is
/// listed for that night rather than for Thursday.
List<TodaysRecitationGroup> buildTodaysRecitationGroups({DateTime? now}) {
  final today = todaysLunarDays(now: now);
  final matches =
      matchTodaysZikrPatterns(itemMetadata, day: today.day, night: today.night);

  final byKind = <TodaysRecitationKind, List<UidTitleData>>{};
  matches.forEach((uid, pattern) {
    final title = items[uid];
    if (title is! String || title.trim().isEmpty) return;
    byKind
        .putIfAbsent(_kindOf(pattern), () => [])
        .add(UidTitleData(uid, title));
  });

  int compare(UidTitleData a, UidTitleData b) {
    final byOrder =
        getItemOrderValue(a.uid).compareTo(getItemOrderValue(b.uid));
    if (byOrder != 0) return byOrder;
    final byId = a.getId().compareTo(b.getId());
    if (byId != 0) return byId;
    return a.uid.compareTo(b.uid);
  }

  return [
    for (final kind in TodaysRecitationKind.values)
      if (byKind[kind] case final items?)
        TodaysRecitationGroup(kind, items..sort(compare)),
  ];
}

TodaysRecitationKind _kindOf(String pattern) =>
    switch (lunarPatternSpecificity(pattern)) {
      0 => pattern.trim().startsWith('N')
          ? TodaysRecitationKind.night
          : TodaysRecitationKind.date,
      1 => TodaysRecitationKind.month,
      2 => TodaysRecitationKind.weekday,
      _ => TodaysRecitationKind.everyDay,
    };
