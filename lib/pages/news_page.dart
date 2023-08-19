import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:shia_companion/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webfeed_revised/domain/rss_feed.dart';

class NewsPage extends StatefulWidget {
  @override
  _NewsPageState createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  RssFeed? data;

  @override
  void initState() {
    trackScreen('News Page');
    getData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getAppBar(),
      body: data != null
          ? ListView.separated(
              separatorBuilder: (context, index) => Divider(),
              itemCount: data!.items!.length,
              itemBuilder: (c, i) {
                return ListTile(
                  // leading:
                  //     Image.network(widget.data.items[i].media.text.value),
                  title: Text(data!.items![i].title ?? ''),
                  subtitle: Text(data!.items![i].description ?? ''),
                  onTap: () {
                    launchBrowser(data!.items![i].link ?? '');
                  },
                );
              })
          : Center(child: CircularProgressIndicator()),
    );
  }

  void launchBrowser(String url) async {
    Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: new Text("No web browser found"),
      ));
    }
  }

  void getData() async {
    Response response = await get(Uri.parse("https://en.abna24.com/rss"));
    if (response.statusCode == 200) {
      data = RssFeed.parse(response.body); // for parsing Atom feed
      setState(() {});
    }
  }
}
