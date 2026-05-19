import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/utils/lunar_date_matcher.dart';

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
  final workingItems = <UidTitleData>[];

  final lunarMatchedUids = getTodaysZikrs(itemMetadata);
  for (final uid in lunarMatchedUids) {
    _insertIfAvailable(workingItems, workingItems.length, uid);
  }

  final today = now ?? DateTime.now();
  final weekdayPrefix = _weekdayPrefix(today);
  for (final rawUid in items.keys) {
    final uid = rawUid.toString();
    if (weekdayPrefix == uid.split('~')[0] ||
        weekdayPrefix == uid.replaceAll(RegExp('[0-9].*'), '')) {
      final title = items[rawUid]?.toString() ?? '';
      if (title.trim().isNotEmpty) {
        workingItems.add(UidTitleData(uid, title));
      }
    }
  }

  workingItems.sort((a, b) {
    return a.getId() > b.getId() ? 1 : -1;
  });

  if (items.isNotEmpty) {
    _insertIfAvailable(workingItems, 1, 'E18');
    _insertIfAvailable(workingItems, 2, 'G6');
    _insertIfAvailable(workingItems, 3, 'G4');
    _insertIfAvailable(workingItems, 4, 'E37');
  }

  return workingItems;
}
