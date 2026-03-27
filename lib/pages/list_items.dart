import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';

import '../constants.dart';

class ItemList extends StatefulWidget {
  final String item, title;

  ItemList(this.item, this.title);

  @override
  _ItemListState createState() => new _ItemListState();
}

class _ItemListState extends State<ItemList> {
  List<UidTitleData> workingItems = [];
  String? _hoveredUid;
  _ItemListState();

  void _refreshWorkingItems() {
    workingItems = [];
    String tableName = widget.item;
    if (widget.item == "D1") tableName = "D";
    tableName = tableName
        .replaceAll(RegExp("[0-9].*"), "")
        .replaceAll(RegExp("[A-Z].*~"), "");
    if (tableName.contains("|"))
      tableName = tableName.split("\\|")[0].replaceAll(RegExp("[0-9].*"), "");

    for (String s in items.keys) {
      if (tableName == s.split("~")[0] ||
          tableName == s.replaceAll(RegExp("[0-9].*"), "")) {
        debugPrint(s + " " + items[s]);
        workingItems.add(UidTitleData(s, items[s]));
      }
    }

    // Populate Today's Recitations
    if (widget.item == "TR") {
      workingItems.add(UidTitleData("E18", items["E18"])); // Dua e Ahad
      workingItems.add(UidTitleData("G6", items["G6"])); // Ziyarat e Waritha
      workingItems.add(UidTitleData("G4", items["G4"])); // Ziyarat e Ashura
      workingItems
          .add(UidTitleData("E37", items["E37"])); // Dua e Sanamay Quraish
      String? tmp;
      DateTime today = DateTime.now();
      if (today.weekday == DateTime.friday) {
        tmp = "J";
      } else if (today.weekday == DateTime.saturday) {
        tmp = "K";
      } else if (today.weekday == DateTime.sunday) {
        tmp = "L";
      } else if (today.weekday == DateTime.monday) {
        tmp = "M";
      } else if (today.weekday == DateTime.tuesday) {
        tmp = "N";
      } else if (today.weekday == DateTime.wednesday) {
        tmp = "O";
      } else if (today.weekday == DateTime.thursday) {
        tmp = "Q";
      }
      for (String s in items.keys) {
        if (tmp == s.split("~")[0] ||
            tmp == s.replaceAll(RegExp("[0-9].*"), "")) {
          debugPrint(s + " " + items[s]);
          workingItems.add(UidTitleData(s, items[s]));
        }
      }
    }
    workingItems.sort((a, b) {
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
  }

  @override
  void initState() {
    super.initState();
    trackScreen('List Item Page');
    _refreshWorkingItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ListView.separated(
        separatorBuilder: (BuildContext context, int index) => Divider(),
        itemCount: workingItems.length,
        itemBuilder: (BuildContext c, int i) =>
            buildZikrRow(c, workingItems[i]),
      ),
    );
  }

  Future<void> _editParentTitle(UidTitleData uidTitleData) async {
    final controller = TextEditingController(text: uidTitleData.title);
    final updatedTitle = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (updatedTitle == null || updatedTitle.isEmpty) return;
    if (updatedTitle == uidTitleData.title) return;

    await FirebaseFirestore.instance
        .collection('zikr')
        .doc(uidTitleData.uid)
        .set({'title': updatedTitle}, SetOptions(merge: true));

    items[uidTitleData.uid] = updatedTitle;

    if (!mounted) return;
    setState(_refreshWorkingItems);
  }

  Widget buildZikrRow(BuildContext context, UidTitleData uidTitleData) {
    UniversalData itemData =
        UniversalData(uidTitleData.uid, uidTitleData.title, 0);
    String title;
    final isParentZikr = uidTitleData.getUId().contains("~");
    if (kDebugMode || isUserAdmin) {
      title = itemData.uid + " " + itemData.title;
    } else {
      title = itemData.title;
    }
    final canShowParentEdit = isUserAdmin && isParentZikr;

    return MouseRegion(
      onEnter: (_) {
        if (canShowParentEdit) {
          setState(() {
            _hoveredUid = uidTitleData.uid;
          });
        }
      },
      onExit: (_) {
        if (_hoveredUid == uidTitleData.uid) {
          setState(() {
            _hoveredUid = null;
          });
        }
      },
      child: ListTile(
        onTap: () async {
          if (isParentZikr) {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => ItemList(
                        uidTitleData.getUId().split("~")[1],
                        uidTitleData.title)));
          } else {
            await handleUniversalDataClick(context, itemData);
          }
          if (!mounted) return;
          setState(_refreshWorkingItems);
        },
        onLongPress: () {
          if (isUserAdmin)
            handleUniversalDataClick(context, itemData, itemPage: true);
        },
        title: Text(title),
        trailing: isParentZikr
            ? canShowParentEdit && (!kIsWeb || _hoveredUid == uidTitleData.uid)
                ? IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit Title',
                    onPressed: () => _editParentTitle(uidTitleData),
                  )
                : null
            : InkWell(
                onTap: () {
                  if (favsData!.contains(itemData)) {
                    favsData!.remove(itemData);
                  } else {
                    favsData!.add(itemData);
                  }
                  setState(() {});
                },
                child: getFavIcon(context, itemData)),
      ),
    );
  }
}
