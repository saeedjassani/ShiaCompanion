import 'package:flutter/material.dart';
import 'package:shia_companion/data/live_streaming_data.dart';
import 'package:shia_companion/pages/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed/domain/atom_feed.dart';
import 'package:webfeed/domain/rss_feed.dart';
import '../constants.dart';

class NewsWidget extends StatefulWidget {
  final RssFeed data;

  NewsWidget(this.data);

  @override
  NewsWidgetState createState() => new NewsWidgetState();
}

class NewsWidgetState extends State<NewsWidget> {
  NewsWidgetState();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        child: ExpansionTile(
          title: Text("Latest News"),
          children: [
            SizedBox(
              height: 300,
              child: ListView.separated(
                  separatorBuilder: (context, index) => Divider(),
                  itemCount: 10,
                  itemBuilder: (c, i) {
                    return ListTile(
                      title: Text(widget.data.items[i].title),
                      subtitle: Text(widget.data.items[i].description),
                      onTap: () {
                        launchBrowser(widget.data.items[i].link);
                      },
                    );
                  }),
            )
          ],
        ),
      ),
    );
  }

  void launchBrowser(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      key.currentState.showSnackBar(new SnackBar(
        content: new Text("No email app found"),
      ));
    }
  }
}
