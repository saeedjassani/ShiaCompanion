import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:shia_companion/data/live_streaming_data.dart';
import 'package:shia_companion/data/universal_data.dart';

import '../constants.dart';
import 'video_player.dart';

class LiveStreamingPage extends StatefulWidget {
  final int arg;

  // 0 for Holy Shrines, 1 for Islamic Channels
  LiveStreamingPage(this.arg);

  @override
  _LiveStreamingPageState createState() => _LiveStreamingPageState();
}

class _LiveStreamingPageState extends State<LiveStreamingPage> {
  List<LiveStreamingData> data;

  @override
  void initState() {
    getData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Shia Companion"),
      ),
      body: data != null
          ? GridView.builder(
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2),
              itemCount: data.length,
              itemBuilder: (BuildContext c, int i) {
                UniversalData universalData =
                    UniversalData(data[i].link, data[i].title, 2);
                return Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Card(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => VideoPlayer(data[i])));
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Image.network(
                            data[i].img,
                            fit: BoxFit.cover,
                            height: 120,
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    data[i].title,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                InkWell(
                                    onTap: () {
                                      favsData.contains(universalData)
                                          ? favsData.remove(universalData)
                                          : favsData.add(universalData);
                                      setState(() {});
                                    },
                                    child: favsData.contains(universalData)
                                        ? Icon(
                                            Icons.star,
                                            color:
                                                Theme.of(context).primaryColor,
                                          )
                                        : Icon(
                                            Icons.star_border,
                                            color:
                                                Theme.of(context).primaryColor,
                                          )),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            )
          : Center(child: CircularProgressIndicator()),
    );
  }

  void getData() async {
    String url = widget.arg == 0
        ? "https://alghazienterprises.com/sc/scripts/getHolyShrines.php"
        : "https://alghazienterprises.com/sc/scripts/getIslamicChannels.php";
    var response = await get(url);
    if (response.statusCode == 200) {
      List x = json.decode(response.body);
      data = List();
      x.forEach((f) => data.add(LiveStreamingData.fromJson(f)));
      setState(() {});
    }
  }
}
