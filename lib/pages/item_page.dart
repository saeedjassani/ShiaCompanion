import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:wakelock/wakelock.dart';

import '../constants.dart';
import '../utils/shared_preferences.dart';
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

  void refreshState() {
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
    if (SP.prefs.getBool('keep_awake') ?? true) Wakelock.enable();
    initializeData();
  }

  void initializeData() async {
    loadString = await DefaultAssetBundle.of(context)
        .loadString('assets/items/' + item.getFirstUId());
    itemData = json.decode(loadString);
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

  TextStyle arabicStyle = TextStyle(
    fontFamily: arabicFont,
    fontSize: arabicFontSize,
  );
  TextStyle transliStyle = TextStyle(
    fontSize: englishFontSize,
  );

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => afterBuild(context));
    List<String>? content =
        itemData != null ? generateCodeAndStrings(itemData['content']) : null;

    return DefaultTabController(
      length: tabs.length,
      child: _tabController != null
          ? Scaffold(
              appBar: AppBar(
                title: Text(item.getTitle()),
                bottom: tabs.length > 1
                    ? TabBar(
                        indicatorColor: Colors.white,
                        tabs: tabs,
                        controller: _tabController,
                      )
                    : null,
                actions: [
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
                              _listController[_tabController!.index].offset);
                        }
                        setState(() {});
                      }),
                  IconButton(
                      icon: Icon(Icons.share),
                      onPressed: () {
                        String shareString =
                            itemData["content"].replaceAll("--", "\n");
                        Share.share(
                            '${item.getTitle()}\n$shareString\n\nShared via Shia Companion - https://www.onelink.to/ShiaCompanion',
                            sharePositionOrigin: Rect.fromLTWH(
                                MediaQuery.of(context).size.width / 2,
                                0,
                                2,
                                2));
                      }),
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
                      child: TabBarView(
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
            )
          : Container(),
    );
  }

  @override
  void dispose() async {
    super.dispose();
    Wakelock.disable();
  }

  List<String> generateCodeAndStrings(String content) {
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
