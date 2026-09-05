import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/widgets/responsive_content.dart';
import 'package:shia_companion/widgets/favorite_icon.dart';

import '../constants.dart';
import '../services/favorites_manager.dart';
import 'package:shia_companion/services/analytics_service.dart';

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
  TextEditingController? controller;
  final CollectionReference<Map<String, dynamic>> _zikrCollection =
      FirebaseFirestore.instance.collection('zikr');

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
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: ResponsiveContent(
        maxWidth: listContentWidth,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          separatorBuilder: (BuildContext context, int index) => Divider(),
          itemCount: workingItems.length,
          itemBuilder: (BuildContext c, int i) =>
              buildZikrRow(c, workingItems[i]),
        ),
      ),
    );
  }

  Future<void> _editTitle(UidTitleData uidTitleData) async {
    controller = TextEditingController(text: uidTitleData.title);
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
                Navigator.pop(dialogContext, controller?.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updatedTitle == null || updatedTitle.isEmpty) return;
    if (updatedTitle == uidTitleData.title) return;

    final docRef =
        FirebaseFirestore.instance.collection('zikr').doc(uidTitleData.uid);
    final docSnap = await docRef.get();
    final docData = docSnap.data();
    final rawSlugAliases = docData?['slugAliases'];
    final existingSlug = normalizeSlug(docData?['slug']?.toString() ?? '');
    final existingAliases = normalizeSlugAliases(
      rawSlugAliases is Iterable ? rawSlugAliases : null,
      exclude: existingSlug,
    );
    final updates = <String, dynamic>{
      'title': updatedTitle,
    };

    if (existingSlug.isEmpty) {
      updates['slug'] = makeUniqueSlug(
        buildSlugSeed(uid: uidTitleData.uid, title: updatedTitle),
        currentUid: uidTitleData.uid,
      );
      if (existingAliases.isNotEmpty) {
        updates['slugAliases'] = existingAliases;
      }
    }

    await docRef.set(updates, SetOptions(merge: true));

    items[uidTitleData.uid] = updatedTitle;
    setLocalSlugData(
      uidTitleData.uid,
      slug: existingSlug.isEmpty ? updates['slug']?.toString() : existingSlug,
      aliases: existingAliases,
    );

    if (!mounted) return;
    setState(_refreshWorkingItems);
  }

  /// Every uid that deleting [uidTitleData] should take with it: the zikr
  /// itself plus the alias documents (`SOMETHING|canonical`) that point at it.
  ///
  /// Alias ids can only be matched by suffix, which Firestore cannot query, so
  /// the set has to be found by looking at every id. Doing that against the
  /// loaded index rather than the `zikr` collection keeps the confirmation
  /// dialog free — the collection scan used to run before the dialog, so even
  /// cancelling cost one billed read per zikr document.
  Set<String> _uidsToDelete(UidTitleData uidTitleData) {
    final canonicalUid = uidTitleData.getFirstUId();
    return {
      for (final uid in items.keys)
        if (uid == canonicalUid ||
            (uid.contains('|')
                ? uid.split('|').last.trim() == canonicalUid
                : uid == uidTitleData.uid))
          uid,
    };
  }

  Future<void> _deleteZikr(UidTitleData uidTitleData) async {
    final canonicalUid = uidTitleData.getFirstUId();
    final localUids = _uidsToDelete(uidTitleData);
    final aliasCount = localUids.length > 1 ? localUids.length - 1 : 0;
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Zikr?'),
            content: Text(
              aliasCount > 0
                  ? 'This will permanently delete "${uidTitleData.title}" and $aliasCount linked alias item(s).'
                  : 'This will permanently delete "${uidTitleData.title}".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    // Only now, once the delete is actually going ahead, pay for the scan —
    // the published index can omit a document that still exists in Firestore,
    // and leaving one of those behind would orphan it.
    final snapshot = await _zikrCollection.get();
    final docsToDelete = snapshot.docs.where((doc) {
      final docUid = doc.id;
      if (localUids.contains(docUid) || docUid == canonicalUid) {
        return true;
      }
      if (!docUid.contains('|')) {
        return docUid == uidTitleData.uid;
      }
      return docUid.split('|').last.trim() == canonicalUid;
    }).toList();

    for (final doc in docsToDelete) {
      await doc.reference.delete();
      items.remove(doc.id);
      itemOrder.remove(doc.id);
      removeLocalSlugData(doc.id);
    }

    if (!mounted) return;
    setState(_refreshWorkingItems);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Deleted successfully. Publish to see changes.'),
      ),
    );
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
    final canShowTitleEdit = kIsWeb && isUserAdmin;
    final showHoverEdit = canShowTitleEdit && _hoveredUid == uidTitleData.uid;

    return MouseRegion(
      onEnter: (_) {
        if (canShowTitleEdit) {
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
            await handleUniversalDataClick(context, itemData,
                source: ZikrOpenSource.list);
          }
          if (!mounted) return;
          setState(_refreshWorkingItems);
        },
        title: Text(title),
        trailing: !isParentZikr
            ? Wrap(
                spacing: 0,
                children: [
                  if (showHoverEdit)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit Title',
                      onPressed: () => _editTitle(uidTitleData),
                    ),
                  if (showHoverEdit)
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete Zikr',
                      onPressed: () => _deleteZikr(uidTitleData),
                    ),
                  InkWell(
                    onTap: () async {
                      await FavoritesManager.instance.toggleFavorite(itemData);
                    },
                    child: FavoriteIcon(favorite: itemData),
                  ),
                ],
              )
            : showHoverEdit
                ? Wrap(
                    spacing: 0,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Edit Title',
                        onPressed: () => _editTitle(uidTitleData),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete Zikr',
                        onPressed: () => _deleteZikr(uidTitleData),
                      ),
                    ],
                  )
                : null,
      ),
    );
  }
}
