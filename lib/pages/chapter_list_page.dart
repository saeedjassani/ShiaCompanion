import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:yaml/yaml.dart';

import 'chapter_page.dart';

class ChapterListPage extends StatefulWidget {
  final String slug;
  final String title;

  ChapterListPage(this.slug, this.title);

  @override
  _ChapterListPageState createState() => new _ChapterListPageState();
}

class _ChapterListPageState extends State<ChapterListPage> {
  List<UidTitleData> chapters = [];

  @override
  void initState() {
    super.initState();
    _updateEventString();
  }

  _updateEventString() async {
    var response = await get(Uri.parse(
        "https://raw.githubusercontent.com/saeedjassani/shiavault-library/master/books/${widget.slug}/metadata.yml"));
    if (response.statusCode == 200) {
      final mapData = loadYaml(response.body.split('---')[1].trim());
      List temp = mapData['chapters'];
      for (var t in temp) {
        chapters.add(UidTitleData(t['slug'], t['title']));
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: chapters.length > 0
          ? ListView.separated(
              shrinkWrap: true,
              itemBuilder: (context, index) => ListTile(
                    title: Text(chapters[index].title),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ChapterPage(
                                widget.slug + "/" + chapters[index].uid,
                                chapters[index].title))),
                  ),
              separatorBuilder: (context, index) => Divider(),
              itemCount: chapters.length)
          : Center(child: CircularProgressIndicator()),
    );
  }
}
