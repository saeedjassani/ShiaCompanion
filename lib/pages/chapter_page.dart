import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart';

class ChapterPage extends StatefulWidget {
  final String slug;
  final String title;

  ChapterPage(this.slug, this.title);

  @override
  _ChapterPageState createState() => new _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  String chapterMarkdown;

  @override
  void initState() {
    super.initState();
    _updateEventString();
  }

  _updateEventString() async {
    var response = await get(
        "https://raw.githubusercontent.com/saeedjassani/shiavault-library/master/books/${widget.slug}.md");
    if (response.statusCode == 200) {
      chapterMarkdown = response.body;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: chapterMarkdown != null
          ? Markdown(data: chapterMarkdown)
          : Center(child: CircularProgressIndicator()),
    );
  }
}
