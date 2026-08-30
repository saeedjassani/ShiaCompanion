import 'package:hijri/hijri_calendar.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/utils/lunar_date_matcher.dart';
import 'package:shia_companion/utils/night_window.dart';

void _insertIfAvailable(
  List<UidTitleData> workingItems,
  int index,
  String uid,
) {
  final title = items[uid];
  if (title is! String || title.trim().isEmpty) return;
  if (workingItems.any((item) => item.uid == uid)) return;
  workingItems.insert(
    index.clamp(0, workingItems.length),
    UidTitleData(uid, title),
  );
}

void _addIfAvailable(List<UidTitleData> workingItems, String uid) {
  _insertIfAvailable(workingItems, workingItems.length, uid);
}

int _compareRecitationItems(UidTitleData a, UidTitleData b) {
  final aOrder = getItemOrderValue(a.uid);
  final bOrder = getItemOrderValue(b.uid);
  if (aOrder != bOrder) {
    return aOrder.compareTo(bOrder);
  }

  final byId = a.getId().compareTo(b.getId());
  if (byId != 0) {
    return byId;
  }

  return a.uid.compareTo(b.uid);
}

String? _weekdayPrefix(DateTime today) {
  return switch (today.weekday) {
    DateTime.friday => 'J',
    DateTime.saturday => 'K',
    DateTime.sunday => 'L',
    DateTime.monday => 'M',
    DateTime.tuesday => 'N',
    DateTime.wednesday => 'O',
    DateTime.thursday => 'Q',
    _ => null,
  };
}

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

  final lunarItems = <UidTitleData>[];
  final lunarMatchedUids = getTodaysZikrs(
    itemMetadata,
    currentDate: adjustedHijriDate,
    nightDate: nightDate,
  );
  for (final uid in lunarMatchedUids) {
    _addIfAvailable(lunarItems, uid);
  }
  lunarItems.sort(_compareRecitationItems);

  final weekdayItems = <UidTitleData>[];
  final weekdayPrefix = _weekdayPrefix(today);
  for (final rawUid in items.keys) {
    final uid = rawUid.toString();
    if (weekdayPrefix == uid.split('~')[0] ||
        weekdayPrefix == uid.replaceAll(RegExp('[0-9].*'), '')) {
      final title = items[rawUid]?.toString() ?? '';
      if (title.trim().isNotEmpty) {
        weekdayItems.add(UidTitleData(uid, title));
      }
    }
  }
  weekdayItems.sort(_compareRecitationItems);

  final workingItems = <UidTitleData>[
    ...lunarItems,
  ];

  for (final item in weekdayItems) {
    _addIfAvailable(workingItems, item.uid);
  }

  if (items.isNotEmpty) {
    _addIfAvailable(workingItems, 'E18');
    _addIfAvailable(workingItems, 'G6');
    _addIfAvailable(workingItems, 'G4');
    _addIfAvailable(workingItems, 'E37');
  }

  return workingItems;
}
