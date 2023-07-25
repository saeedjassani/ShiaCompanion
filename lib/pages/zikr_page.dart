import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:http/http.dart';
import '../constants.dart';

class ZikrPage extends StatefulWidget {
  final UidTitleData item;

  ZikrPage(this.item);

  @override
  _ZikrPageState createState() => new _ZikrPageState(item);
}

class _ZikrPageState extends State<ZikrPage> {
  final UidTitleData item;

  Set<int> arabicCodes = Set(), transliCodes = Set(), translaCodes = Set();

  _ZikrPageState(this.item);
  var itemData;
  List<String>? content;
  @override
  void initState() {
    super.initState();
    initializeData();
  }

  TextStyle arabicStyle = TextStyle(
    fontFamily: "Qalam",
    fontSize: arabicFontSize,
  );
  TextStyle transliStyle =
      TextStyle(fontWeight: FontWeight.bold, fontSize: englishFontSize);

  void initializeData() async {
    String jsonString = "";
    if (kReleaseMode) {
      jsonString = await DefaultAssetBundle.of(context)
          .loadString("assets/zikr/${item.getFirstUId()}");
    } else {
      String url =
          "https://alghazienterprises.com/sc/scripts/getItem.php?uid=${item.getFirstUId()}";
      debugPrint(url);
      var request = await get(Uri.parse(url));
      jsonString = request.body;
    }
    itemData = json.decode(jsonString);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (itemData != null && itemData['data'] != null)
      content = generateCodeAndStrings1(itemData['data']);

    return Scaffold(
      appBar: getAppBar(),
      body: content != null
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                itemCount: content!.length,
                itemBuilder: (BuildContext c, int i) {
                  String str = content![i].trim();

                  if (arabicCodes.contains(i)) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        str,
                        style: arabicStyle,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),
                    );
                  } else if (transliCodes.contains(i)) {
                    return showTransliteration
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 4.0),
                            child: Text(
                              str.toUpperCase(),
                              style: transliStyle,
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Container();
                  } else if (translaCodes.contains(i)) {
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
                      child: Text(
                        str,
                      ),
                    );
                  }
                },
              ),
            )
          : Center(child: CircularProgressIndicator()),
    );
  }

  List<String> generateCodeAndStrings(String content) {
    List<String> split = content.split("--");

    for (int i = 0, n = split.length; i < n; i++) {
      if (split[i].trim().isEmpty) continue;
      if (isArabic(split[i])) {
        arabicCodes.add(i);
      }
    }
    return split;
  }

  List<String> generateCodeAndStrings1(String content) {
    List<String> split = content.split("\n");

    for (int i = 0, n = split.length; i < n; i++) {
      split[i] = split[i].trim();
      if (split[i].isEmpty) continue;
      if (isArabic(split[i])) {
        arabicCodes.add(i);
      }
    }

    generateOtherCodes();

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

  void generateOtherCodes() {
    String code = itemData['code'];
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
}
