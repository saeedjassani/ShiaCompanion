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
  TextEditingController? meritsController;
  TextEditingController? orderController;
  final List<TextEditingController> tabControllers = [];
  final List<ScrollController> _tabScrollControllers = [];
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

  @override
  void dispose() {
    titleController?.dispose();
    codeController?.dispose();
    dataController?.dispose();
    meritsController?.dispose();
    orderController?.dispose();
    for (final controller in tabControllers) {
      controller.dispose();
    }
    for (final controller in _tabScrollControllers) {
      controller.dispose();
    }
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
        meritsController = TextEditingController(text: zikrData?['merits']);
        final rawTabs = zikrData?['tabs'];
        if (rawTabs is List) {
          for (final controller in tabControllers) {
            controller.dispose();
          }
          tabControllers.clear();
          for (final tab in rawTabs) {
            tabControllers
                .add(TextEditingController(text: tab?.toString() ?? ''));
          }
        }
        final double? currentOrder = itemOrder[widget.item.uid];
        orderController = TextEditingController(
            text: currentOrder == null
                ? ''
                : (currentOrder % 1 == 0
                    ? currentOrder.toInt().toString()
                    : currentOrder.toString()));
        _syncTabScrollControllers(_buildVisibleTabContents().length);
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
      final savedTabs = tabControllers
          .map((controller) => controller.text)
          .where((content) => content.trim().isNotEmpty)
          .toList();
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
        'merits': (meritsController?.text.trim().isEmpty ?? true)
            ? FieldValue.delete()
            : meritsController?.text,
        'tabs': savedTabs.isEmpty ? FieldValue.delete() : savedTabs,
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
        zikrData?['merits'] = meritsController?.text;
        zikrData?['tabs'] = savedTabs;
        _syncTabScrollControllers(_buildVisibleTabContents().length);
      });
    }
  }

  void _addTabField() {
    setState(() {
      tabControllers.add(TextEditingController());
    });
  }

  void _showMeritsSheet() {
    final merits = meritsController?.text.trim() ?? '';
    if (merits.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Merits',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    SelectableText(
                      merits,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _buildVisibleTabContents() {
    final primary = dataController?.text ?? zikrData?['data']?.toString() ?? '';
    final extraTabs = <String>[];
    final rawTabs = zikrData?['tabs'];

    if (tabControllers.isNotEmpty) {
      extraTabs.addAll(tabControllers.map((controller) => controller.text));
    } else if (rawTabs is List) {
      extraTabs.addAll(rawTabs.map((tab) => tab?.toString() ?? ''));
    }

    final visibleTabs = <String>[];
    if (primary.trim().isNotEmpty ||
        extraTabs.every((tab) => tab.trim().isEmpty)) {
      visibleTabs.add(primary);
    }
    visibleTabs.addAll(extraTabs.where((tab) => tab.trim().isNotEmpty));
    return visibleTabs;
  }

  void _syncTabScrollControllers(int count) {
    while (_tabScrollControllers.length < count) {
      _tabScrollControllers.add(ScrollController());
    }
    while (_tabScrollControllers.length > count) {
      _tabScrollControllers.removeLast().dispose();
    }
  }

  String _getTabHeader(String content, int index) {
    final lines = content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    if (lines.isNotEmpty) {
      return lines.first;
    }
    return 'Tab ${index + 1}';
  }

  Widget _buildTabContent(String rawContent, ScrollController controller) {
    final parsedContent = _parseContent(rawContent);

    return Scrollbar(
      controller: controller,
      child: ListView.builder(
        controller: controller,
        itemCount: parsedContent.lines.length,
        itemBuilder: (BuildContext context, int index) {
          final str = parsedContent.lines[index].trim();

          if (parsedContent.arabicCodes.contains(index)) {
            return Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
              child: Text(
                formatArabicText(str),
                style: arabicStyle,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            );
          } else if (parsedContent.transliCodes.contains(index)) {
            return showTransliteration
                ? Text(
                    str.toUpperCase(),
                    style: transliStyle,
                    textAlign: TextAlign.center,
                  )
                : Container();
          } else if (parsedContent.translaCodes.contains(index)) {
            return showTranslation
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Text(
                      str,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: englishFontSize),
                    ),
                  )
                : Container();
          } else {
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4.0),
              child: Text(str),
            );
          }
        },
      ),
    );
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
    final merits = meritsController?.text.trim() ?? '';
    final hasMerits = merits.isNotEmpty;
    final tabContents = _buildVisibleTabContents();
    _syncTabScrollControllers(tabContents.length);
    final hasAnyContent =
        tabContents.any((content) => content.trim().isNotEmpty);

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
                : !hasAnyContent && !isEditing
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
                                    TextField(
                                      controller: meritsController,
                                      decoration: const InputDecoration(
                                          labelText: 'Merits'),
                                      maxLines: null,
                                    ),
                                    const SizedBox(height: 12),
                                    OutlinedButton.icon(
                                      onPressed: _addTabField,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Add Tab'),
                                    ),
                                    for (int i = 0;
                                        i < tabControllers.length;
                                        i++)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: TextField(
                                          controller: tabControllers[i],
                                          decoration: InputDecoration(
                                            labelText: 'Tab ${i + 1}',
                                            helperText:
                                                'First line becomes the tab title',
                                          ),
                                          maxLines: null,
                                        ),
                                      ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  if (hasMerits)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: TextButton.icon(
                                          onPressed: _showMeritsSheet,
                                          icon: const Icon(Icons.open_in_new),
                                          label: const Text(
                                            'Merits',
                                            style: TextStyle(
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            visualDensity:
                                                VisualDensity.compact,
                                            alignment: Alignment.centerLeft,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: DefaultTabController(
                                      length: tabContents.length,
                                      child: Column(
                                        children: [
                                          if (tabContents.length > 1)
                                            Container(
                                              width: double.infinity,
                                              margin: const EdgeInsets.only(
                                                  bottom: 16),
                                              child: TabBar(
                                                isScrollable: true,
                                                dividerColor:
                                                    Colors.transparent,
                                                splashBorderRadius:
                                                    BorderRadius.circular(999),
                                                labelColor: Theme.of(context)
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                                unselectedLabelColor:
                                                    Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                indicator: BoxDecoration(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primaryContainer,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                labelPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6),
                                                tabs: List.generate(
                                                  tabContents.length,
                                                  (index) => Tab(
                                                    text: _getTabHeader(
                                                        tabContents[index],
                                                        index),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          Expanded(
                                            child: TabBarView(
                                              children: List.generate(
                                                tabContents.length,
                                                (index) => _buildTabContent(
                                                  tabContents[index],
                                                  _tabScrollControllers[index],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
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

  _ParsedZikrContent _parseContent(String content) {
    final split = content.split('\n');
    final arabicCodes = <int>{};

    for (int i = 0, n = split.length; i < n; i++) {
      split[i] = split[i].trim();
      if (split[i].isEmpty) continue;
      if (isArabic(split[i])) {
        arabicCodes.add(i);
      }
    }

    return _ParsedZikrContent(
      lines: split,
      arabicCodes: arabicCodes,
      transliCodes: _generateEnglishCodes(arabicCodes, true),
      translaCodes: _generateEnglishCodes(arabicCodes, false),
    );
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

  Set<int> _generateEnglishCodes(Set<int> arabicCodes, bool transliteration) {
    final englishCodes = <int>{};
    String code = zikrData?['code'];
    if (code == "102") {
      for (final i in arabicCodes) {
        englishCodes.add(transliteration ? i - 1 : i + 1);
      }
    } else if (code == "012") {
      for (final i in arabicCodes) {
        englishCodes.add(transliteration ? i + 1 : i + 2);
      }
    } else if (code == "02" && !transliteration) {
      for (final i in arabicCodes) {
        englishCodes.add(i + 1);
      }
    }
    return englishCodes;
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

class _ParsedZikrContent {
  final List<String> lines;
  final Set<int> arabicCodes;
  final Set<int> transliCodes;
  final Set<int> translaCodes;

  const _ParsedZikrContent({
    required this.lines,
    required this.arabicCodes,
    required this.transliCodes,
    required this.translaCodes,
  });
}
