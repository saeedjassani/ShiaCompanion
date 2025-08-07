import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import '../constants.dart';
import '../widgets/zikr_settings.dart';

class ZikrPage extends StatefulWidget {
  final UidTitleData item;
  ZikrPage(this.item);

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
  List<String>? content;
  Set<int> arabicCodes = Set(), transliCodes = Set(), translaCodes = Set();

  TextStyle arabicStyle = TextStyle(
    fontFamily: arabicFont,
    fontSize: arabicFontSize,
  );
  TextStyle transliStyle =
      TextStyle(fontWeight: FontWeight.bold, fontSize: englishFontSize);

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _fetchZikrData();
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
    final doc = await zikrCollection.doc(widget.item.uid).get();
    if (doc.exists) {
      setState(() {
        zikrData = doc.data() as Map<String, dynamic>;
        titleController = TextEditingController(text: zikrData?['title']);
        codeController = TextEditingController(text: zikrData?['code']);
        dataController = TextEditingController(text: zikrData?['data']);
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
      await zikrCollection.doc(widget.item.uid).update({
        'title': titleController?.text,
        'code': codeController?.text,
        'data': dataController?.text,
      });
      setState(() {
        isEditing = false;
        zikrData?['title'] = titleController?.text;
        zikrData?['code'] = codeController?.text;
        zikrData?['data'] = dataController?.text;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (zikrData != null && zikrData?['data'] != null)
      content = populateArabicContent(zikrData?['data']);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.title),
        actions: [
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
      body: zikrData == null
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: isEditing
                  ? SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: titleController,
                            decoration: InputDecoration(labelText: 'Title'),
                          ),
                          TextField(
                            controller: codeController,
                            decoration: InputDecoration(
                                helperMaxLines: 3,
                                helperText:
                                    'Blank for Only Arabic, 0 for Arabic, 1 for transliteration, 2 for translation. Example: 012 will have Arabic, transliteration, and translation. 02 for Arabic and translation only',
                                labelText: 'Code'),
                          ),
                          TextField(
                            controller: dataController,
                            decoration: InputDecoration(labelText: 'Data'),
                            maxLines: null,
                          ),
                          SizedBox(height: 16),
                          TextButton.icon(
                            label: Text('Save Changes'),
                            icon: Icon(Icons.save),
                            onPressed: _saveEdits,
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListView.builder(
                        itemCount: content!.length,
                        itemBuilder: (BuildContext c, int i) {
                          String str = content![i].trim();

                          if (arabicCodes.contains(i)) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                formatArabicText(str),
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
                                      style:
                                          TextStyle(fontSize: englishFontSize),
                                    ),
                                  )
                                : Container();
                          } else {
                            return Padding(
                              padding:
                                  const EdgeInsets.only(top: 8, bottom: 4.0),
                              child: Text(
                                str,
                              ),
                            );
                          }
                        },
                      ),
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
          .replaceAll("ۃ", "ة");
    }
  }

  void refreshState() {
    arabicStyle = TextStyle(
      fontFamily: arabicFont,
      fontSize: arabicFontSize,
    );
    transliStyle =
        TextStyle(fontWeight: FontWeight.bold, fontSize: englishFontSize);
    setState(() {});
  }
}
