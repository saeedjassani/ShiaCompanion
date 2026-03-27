import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import '../constants.dart';
import '../widgets/zikr_settings.dart';
import '../widgets/zikr_counter.dart';
// import 'zikr_counters_list_page.dart';

class ZikrPage extends StatefulWidget {
  final UidTitleData item;
  final bool startEditing;
  ZikrPage(this.item, {this.startEditing = false});

  @override
  _ZikrPageState createState() => _ZikrPageState();
}

class _ZikrPageState extends State<ZikrPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference zikrCollection =
      FirebaseFirestore.instance.collection('zikr');

  bool isAdmin = false;
  bool isEditing = false;
  String? userId;
  Map<String, dynamic>? zikrData;
  TextEditingController? titleController;
  TextEditingController? codeController;
  TextEditingController? dataController;
  TextEditingController? orderController;
  List<String>? content;
  Set<int> arabicCodes = Set(), transliCodes = Set(), translaCodes = Set();
  final RegExp _numericOrderPattern = RegExp(r'^-?\d+(\.\d+)?$');

  TextStyle arabicStyle = TextStyle(
      fontFamily: arabicFont, fontSize: arabicFontSize, letterSpacing: 0);
  TextStyle transliStyle =
      TextStyle(fontWeight: FontWeight.bold, fontSize: englishFontSize);

  @override
  void initState() {
    super.initState();
    if (widget.startEditing) {
      isEditing = true;
    }
    _checkAdmin();
    _fetchZikrData();
  }

  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    titleController?.dispose();
    codeController?.dispose();
    dataController?.dispose();
    orderController?.dispose();
    super.dispose();
  }

  Future<void> _checkAdmin() async {
    final user = _auth.currentUser;
    if (user != null) {
      setState(() {
        userId = user.uid;
      });
      final idTokenResult = await user.getIdTokenResult(true);
      final claims = idTokenResult.claims;
      if (claims != null && claims['admin'] == true) {
        setState(() {
          isAdmin = true;
        });
      }
    }
  }

  Future<void> _fetchZikrData() async {
    final doc = await zikrCollection.doc(widget.item.getFirstUId()).get();
    if (doc.exists) {
      setState(() {
        zikrData = doc.data() as Map<String, dynamic>;
        titleController = TextEditingController(text: zikrData?['title']);
        codeController = TextEditingController(text: zikrData?['code']);
        dataController = TextEditingController(text: zikrData?['data']);
        final double? currentOrder = itemOrder[widget.item.uid];
        orderController = TextEditingController(
            text: currentOrder == null
                ? ''
                : (currentOrder % 1 == 0
                    ? currentOrder.toInt().toString()
                    : currentOrder.toString()));
      });
    }
  }

  void _toggleEdit() {
    setState(() {
      isEditing = !isEditing;
    });
  }

  Future<void> _saveEdits() async {
    if (zikrData != null) {
      final rawOrder = orderController?.text.trim() ?? '';
      if (rawOrder.isNotEmpty && !_numericOrderPattern.hasMatch(rawOrder)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Order must be a number (examples: -2, 5, 5.5) or left blank'),
        ));
        return;
      }
      final parsedOrder = rawOrder.isEmpty ? null : double.parse(rawOrder);

      await zikrCollection.doc(widget.item.uid).update({
        'title': titleController?.text,
        'code': codeController?.text,
        'data': dataController?.text,
        'order': parsedOrder ?? FieldValue.delete(),
      });
      if (parsedOrder == null) {
        itemOrder.remove(widget.item.uid);
      } else {
        itemOrder[widget.item.uid] = parsedOrder;
      }
      setState(() {
        isEditing = false;
        zikrData?['title'] = titleController?.text;
        zikrData?['code'] = codeController?.text;
        zikrData?['data'] = dataController?.text;
      });
    }
  }

  Future<void> _deleteZikr() async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete Zikr?'),
            content: Text(
              'This will permanently delete "${titleController?.text ?? widget.item.title}".',
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

    await zikrCollection.doc(widget.item.uid).delete();
    items.remove(widget.item.uid);
    itemOrder.remove(widget.item.uid);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (zikrData != null && zikrData?['data'] != null)
      content = populateArabicContent(zikrData?['data']);

    // Counter overlay state
    ValueNotifier<Offset> counterOffset = ValueNotifier(const Offset(20, 80));
    ValueNotifier<bool> showCounter = ValueNotifier(false);

    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.item.title),
          actions: [
            if (isAdmin && zikrData != null && isEditing)
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Delete Zikr',
                onPressed: _deleteZikr,
              ),
            if (isAdmin && zikrData != null && isEditing)
              IconButton(
                icon: const Icon(Icons.done),
                tooltip: 'Save Changes',
                onPressed: _saveEdits,
              ),
            isAdmin && zikrData != null
                ? IconButton(
                    icon: Icon(isEditing ? Icons.close : Icons.edit),
                    onPressed: _toggleEdit,
                  )
                : Container(),
            Builder(builder: (BuildContext innerContext) {
              return IconButton(
                icon: Icon(Icons.filter_list),
                onPressed: () => Scaffold.of(innerContext).openEndDrawer(),
              );
            }),
          ],
        ),
        endDrawer: ZikrSettingsPage(refreshState),
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: showCounter,
          builder: (context, visible, _) => visible
              ? const SizedBox.shrink()
              : FloatingActionButton(
                  onPressed: () => showCounter.value = true,
                  tooltip: 'Show Counter',
                  child: const Icon(Icons.exposure_plus_1),
                ),
        ),
        body: Stack(
          children: [
            zikrData == null
                ? const Center(child: CircularProgressIndicator())
                : zikrData?['data'] == '' && !isEditing
                    ? const Center(child: Text('Coming soon...'))
                    : Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: isEditing
                            ? SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: titleController,
                                      decoration: const InputDecoration(
                                          labelText: 'Title'),
                                    ),
                                    TextField(
                                      controller: codeController,
                                      decoration: const InputDecoration(
                                          helperMaxLines: 3,
                                          helperText:
                                              'Blank for Only Arabic, 0 for Arabic, 1 for transliteration, 2 for translation. Example: 012 will have Arabic, transliteration, and translation. 02 for Arabic and translation only',
                                          labelText: 'Code'),
                                    ),
                                    TextField(
                                      controller: orderController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Order',
                                        helperText:
                                            'Custom list order for this zikr',
                                      ),
                                    ),
                                    TextField(
                                      controller: dataController,
                                      decoration: const InputDecoration(
                                          labelText: 'Data'),
                                      maxLines: null,
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  Expanded(
                                    child: Scrollbar(
                                      controller: _controller,
                                      child: ListView.builder(
                                        controller: _controller,
                                        itemCount: content?.length ?? 0,
                                        itemBuilder: (BuildContext c, int i) {
                                          String str = content![i].trim();

                                          if (arabicCodes.contains(i)) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 12.0, bottom: 4.0),
                                              child: Text(
                                                formatArabicText(str),
                                                style: arabicStyle,
                                                textAlign: TextAlign.center,
                                                textDirection:
                                                    TextDirection.rtl,
                                              ),
                                            );
                                          } else if (transliCodes.contains(i)) {
                                            return showTransliteration
                                                ? Text(
                                                    str.toUpperCase(),
                                                    style: transliStyle,
                                                    textAlign: TextAlign.center,
                                                  )
                                                : Container();
                                          } else if (translaCodes.contains(i)) {
                                            return showTranslation
                                                ? Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            bottom: 4.0),
                                                    child: Text(
                                                      str,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                          fontSize:
                                                              englishFontSize),
                                                    ),
                                                  )
                                                : Container();
                                          } else {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                  top: 8, bottom: 4.0),
                                              child: Text(
                                                str,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
            // Counter overlay
            ValueListenableBuilder<bool>(
              valueListenable: showCounter,
              builder: (context, visible, _) {
                if (!visible) return const SizedBox.shrink();
                return ValueListenableBuilder<Offset>(
                  valueListenable: counterOffset,
                  builder: (context, offset, __) => Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    child: Draggable(
                      feedback: Material(
                        color: Colors.transparent,
                        child: ZikrCounter(zikrId: widget.item.uid),
                      ),
                      childWhenDragging: const SizedBox.shrink(),
                      onDragEnd: (details) {
                        counterOffset.value = details.offset;
                      },
                      child: Stack(
                        children: [
                          ZikrCounter(zikrId: widget.item.uid),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => showCounter.value = false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<String> populateArabicContent(String content) {
    List<String> split = content.split("\n");

    for (int i = 0, n = split.length; i < n; i++) {
      split[i] = split[i].trim();
      if (split[i].isEmpty) continue;
      if (isArabic(split[i])) {
        arabicCodes.add(i);
      }
    }

    generateEnglishCodes();

    return split;
  }

  bool isArabic(String s) {
    for (int i = 0, n = s.length; i < n && i < 35;) {
      int c = s.codeUnitAt(i);
      if (c >= 0x0600 && c <= 0x06E0) {
        return true;
      }
      i += c.bitLength;
    }
    return false;
  }

  void generateEnglishCodes() {
    String code = zikrData?['code'];
    if (code == "102") {
      arabicCodes.forEach((int i) {
        transliCodes.add(i - 1);
      });
      arabicCodes.forEach((int i) {
        translaCodes.add(i + 1);
      });
    } else if (code == "012") {
      arabicCodes.forEach((int i) {
        transliCodes.add(i + 1);
      });
      arabicCodes.forEach((int i) {
        translaCodes.add(i + 2);
      });
    } else if (code == "02") {
      arabicCodes.forEach((int i) {
        translaCodes.add(i + 1);
      });
    }
  }

  String formatArabicText(String str) {
    if (arabicFont == 'Qalam') {
      return str;
    } else {
      return str
          .replaceAll("ی", "ي")
          .replaceAll("ہ", "ه")
          .replaceAll("ک", "ك")
          .replaceAll("ۃ", "ة")
          .replaceAll('الله', 'اللّٰه');
    }
  }

  void refreshState() {
    arabicStyle = TextStyle(
        fontFamily: arabicFont, fontSize: arabicFontSize, letterSpacing: 0);
    transliStyle =
        TextStyle(fontWeight: FontWeight.bold, fontSize: englishFontSize);
    setState(() {});
  }
}
