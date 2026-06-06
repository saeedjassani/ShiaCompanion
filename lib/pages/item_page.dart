import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/data/uid_title_data.dart';

import '../constants.dart';
import '../utils/shared_preferences.dart';
import '../utils/zikr_wakelock.dart';
import '../widgets/zikr_settings.dart';

class ItemPage extends StatefulWidget {
  final UidTitleData item;

  ItemPage(this.item);

  @override
  _ItemPageState createState() => new _ItemPageState(item);
}

class _ItemPageState extends State<ItemPage> with TickerProviderStateMixin {
  final UidTitleData item;

  Set<int> codes = Set();
  TabController? _tabController;
  bool isEditing = false;
  final TextEditingController _contentEditController = TextEditingController();
  final TextEditingController _englishEditController = TextEditingController();
  final TextEditingController _transliterationEditController =
      TextEditingController();

  void refreshState() {
    syncZikrWakelockPreference(owner: this, isActive: true);
    setState(() {});
  }

  _ItemPageState(this.item);

  late String loadString;
  var itemData;
  List<Tab> tabs = [
    Tab(text: 'Arabic'),
  ];
  List<Widget> children = [];
  List<ScrollController> _listController = [ScrollController()];

  @override
  void initState() {
    super.initState();
    trackScreen('Item Page');
    syncZikrWakelockPreference(owner: this, isActive: true);
    initializeData();
  }

  void initializeData() async {
    loadString = await DefaultAssetBundle.of(context)
        .loadString('assets/items/' + item.getFirstUId());
    if (!mounted) return;
    itemData = json.decode(loadString);
    _resetEditControllers();
    if (itemData['english'] != null && itemData['english'] != '') {
      _listController.add(ScrollController());
      tabs.add(Tab(text: 'Translation'));
      children.add(SingleChildScrollView(
          controller: _listController.last, child: Text(itemData['english'])));
    }
    if (itemData['transliteration'] != null &&
        itemData['transliteration'] != '') {
      _listController.add(ScrollController());
      tabs.add(Tab(text: 'Transliteration'));
      children.add(SingleChildScrollView(
          controller: _listController.last,
          child: Text(itemData['transliteration'])));
    }
    _tabController = TabController(length: tabs.length, vsync: this);
    _tabController?.addListener(() {
      setState(() {});
    });
    setState(() {});
  }

  String _itemField(String key) {
    if (itemData is Map && itemData[key] != null) {
      return itemData[key].toString();
    }
    return '';
  }

  String _itemContentForCopy() {
    return _itemField('content').replaceAll("--", "\n").trim();
  }

  void _resetEditControllers() {
    _contentEditController.text = _itemContentForCopy();
    _englishEditController.text = _itemField('english').trim();
    _transliterationEditController.text = _itemField('transliteration').trim();
  }

  void _toggleEdit() {
    setState(() {
      if (!isEditing) {
        _resetEditControllers();
      }
      isEditing = !isEditing;
    });
  }

  TextStyle arabicStyle = TextStyle(
    fontFamily: arabicFont,
    fontSize: arabicFontSize,
  );
  TextStyle transliStyle = TextStyle(
    fontSize: englishFontSize,
  );

  @override
  Widget build(BuildContext context) {
    if (!isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => afterBuild(context));
    }
    List<String>? content =
        itemData != null ? generateCodeAndStrings(_itemField('content')) : null;

    return DefaultTabController(
      length: tabs.length,
      child: _tabController != null
          ? SelectionArea(
              child: Scaffold(
                appBar: AppBar(
                  title: Text(item.getTitle()),
                  bottom: !isEditing && tabs.length > 1
                      ? TabBar(
                          indicatorColor: Colors.white,
                          tabs: tabs,
                          controller: _tabController,
                        )
                      : null,
                  actions: [
                    if (!isEditing)
                      IconButton(
                          icon: Icon(SP.prefs.containsKey(
                                  _tabController!.index.toString() +
                                      "scroll_" +
                                      item.getUId())
                              ? Icons.bookmark
                              : Icons.bookmark_border),
                          onPressed: () async {
                            if (SP.prefs.containsKey(
                                _tabController!.index.toString() +
                                    "scroll_" +
                                    item.getUId())) {
                              SP.prefs.remove(_tabController!.index.toString() +
                                  "scroll_" +
                                  item.getUId());
                            } else {
                              await SP.prefs.setDouble(
                                  _tabController!.index.toString() +
                                      "scroll_" +
                                      item.getUId(),
                                  _listController[_tabController!.index]
                                      .offset);
                            }
                            setState(() {});
                          }),
                    if (!isEditing)
                      IconButton(
                          icon: Icon(Icons.share),
                          onPressed: () {
                            String shareString = _itemContentForCopy();
                            SharePlus.instance.share(ShareParams(
                              text:
                                  '${item.getTitle()}\n$shareString\n\nShared via Shia Companion - https://www.onelink.to/ShiaCompanion',
                              sharePositionOrigin: Rect.fromLTWH(
                                  MediaQuery.of(context).size.width / 2,
                                  0,
                                  2,
                                  2),
                            ));
                          }),
                    if (isUserAdmin && itemData != null)
                      IconButton(
                        icon: Icon(isEditing ? Icons.close : Icons.edit),
                        tooltip: isEditing ? 'Close Edit' : 'Edit',
                        onPressed: _toggleEdit,
                      ),
                    Builder(builder: (context) {
                      return IconButton(
                        icon: Icon(Icons.filter_list),
                        onPressed: () => Scaffold.of(context).openEndDrawer(),
                      );
                    }),
                  ],
                ),
                endDrawer: ZikrSettingsPage(refreshState),
                body: itemData != null
                    ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: isEditing
                            ? _buildEditFields()
                            : TabBarView(
                                controller: _tabController,
                                children: [
                                  ListView.builder(
                                    controller: _listController[0],
                                    itemCount: content?.length,
                                    itemBuilder: (BuildContext c, int i) {
                                      String? str = content?[i].trim();
                                      if (codes.contains(i)) {
                                        return Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            str ?? "",
                                            style: arabicStyle,
                                            textAlign: TextAlign.center,
                                            textDirection: TextDirection.rtl,
                                          ),
                                        );
                                      } else {
                                        return Text(
                                          str ?? "",
                                          style: transliStyle,
                                        );
                                      }
                                    },
                                  ),
                                  ...children
                                ],
                              ),
                      )
                    : Text(''),
              ),
            )
          : Container(),
    );
  }

  Widget _buildEditFields() {
    return ListView(
      children: [
        _buildEditTextField(
          controller: _contentEditController,
          label: 'Arabic',
          minLines: 10,
        ),
        const SizedBox(height: 16),
        _buildEditTextField(
          controller: _englishEditController,
          label: 'Translation',
          minLines: 8,
        ),
        const SizedBox(height: 16),
        _buildEditTextField(
          controller: _transliterationEditController,
          label: 'Transliteration',
          minLines: 8,
        ),
      ],
    );
  }

  Widget _buildEditTextField({
    required TextEditingController controller,
    required String label,
    required int minLines,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.multiline,
      minLines: minLines,
      maxLines: null,
      decoration: InputDecoration(
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
        labelText: label,
      ),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    for (final controller in _listController) {
      controller.dispose();
    }
    _contentEditController.dispose();
    _englishEditController.dispose();
    _transliterationEditController.dispose();
    syncZikrWakelockPreference(owner: this, isActive: false);
    super.dispose();
  }

  List<String> generateCodeAndStrings(String content) {
    codes.clear();
    List<String> split =
        content.split("--"); //.replaceAll("\u200c", "") - Do not replace this.
    for (int i = 0, n = split.length; i < n; i++) {
      if (split[i].trim().isEmpty) continue;
      if (isArabic(split[i])) codes.add(i);
    }
    return split;
  }

  bool isArabic(String s) {
    var runes = s.runes.toList();
    for (int i = 0, n = s.runes.length; i < n && i < 5;) {
      int c = runes[i];
      if (c >= 0x0600 && c <= 0x06E0) return true;
      i++;
    }
    return false;
  }

  void afterBuild(BuildContext context) async {
    if (_tabController != null) {
      if (_listController[_tabController!.index].hasClients &&
          SP.prefs.containsKey(
              _tabController!.index.toString() + "scroll_" + item.getUId())) {
        _listController[_tabController!.index].jumpTo(SP.prefs.getDouble(
                _tabController!.index.toString() + "scroll_" + item.getUId()) ??
            0.0);
      }
    }
  }
}
