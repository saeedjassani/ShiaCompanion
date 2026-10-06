import '../constants.dart';
import '../data/uid_title_data.dart';

/// The entries of zikr list [item] ("E" for Duas, "G" for Ziyarats, the
/// part after a group's `~`), in the order the list shows them.
List<UidTitleData> zikrListEntries(String item) {
  String tableName = item;
  if (item == "D1") tableName = "D";
  tableName = tableName
      .replaceAll(RegExp("[0-9].*"), "")
      .replaceAll(RegExp("[A-Z].*~"), "");
  if (tableName.contains("|"))
    tableName = tableName.split("\\|")[0].replaceAll(RegExp("[0-9].*"), "");

  final entries = <UidTitleData>[];
  for (String s in items.keys) {
    if (tableName == s.split("~")[0] ||
        tableName == s.replaceAll(RegExp("[0-9].*"), "")) {
      entries.add(UidTitleData(s, items[s]));
    }
  }
  entries.sort((a, b) {
    final double aOrder = getItemOrderValue(a.getUId());
    final double bOrder = getItemOrderValue(b.getUId());
    if (aOrder != bOrder) {
      return aOrder.compareTo(bOrder);
    }
    final int byId = a.getId().compareTo(b.getId());
    if (byId != 0) {
      return byId;
    }
    return a.getUId().compareTo(b.getUId());
  });
  return entries;
}

/// Whether [entry] opens a group of zikr rather than a zikr.
bool isZikrGroup(UidTitleData entry) => entry.getUId().contains("~");

/// Where each zikr sits in the lists, as search names it under a result:
/// "Ziyarats", "Aamaal › Muharram". [roots] are the lists the menu opens,
/// each with its name; a zikr in more than one is placed in the first.
///
/// Group rows are placed too, by the list they sit in. Aliases
/// ("<uid>|<target>") are not: search never lists them.
Map<String, String> zikrLocations(
  List<(String list, String name)> roots, {
  required String Function(String parent, String child) join,
}) {
  final locations = <String, String>{};
  final visited = <String>{};

  void visit(String list, String path, int depth) {
    if (depth > 4 || !visited.add(list)) return;
    for (final entry in zikrListEntries(list)) {
      if (entry.uid.contains('|')) continue;
      locations.putIfAbsent(entry.uid, () => path);
      if (isZikrGroup(entry)) {
        visit(
            entry.uid.split('~')[1], join(path, entry.displayTitle), depth + 1);
      }
    }
  }

  for (final (list, name) in roots) {
    visit(list, name, 0);
  }
  return locations;
}
