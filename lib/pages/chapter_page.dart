import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:http/http.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

import '../constants.dart';

class ChapterPage extends StatefulWidget {
  final String slug;
  final String title;

  ChapterPage(this.slug, this.title);

  @override
  _ChapterPageState createState() => new _ChapterPageState();
}

class _ChapterPageState extends State<ChapterPage> {
  String? chapterMarkdown;

  @override
  void initState() {
    super.initState();
    trackScreen('Chapter Page');
    _updateEventString();
  }

  _updateEventString() async {
    var response = await get(Uri.parse(
        "https://raw.githubusercontent.com/saeedjassani/shiavault-library/master/books/${widget.slug}.md"));
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
          ? ResponsiveContent(
              maxWidth: readingContentWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Markdown(
                data: chapterMarkdown!,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
