import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import '../data/universal_data.dart';

import '../constants.dart';
import 'video_player.dart';

class NewsPage extends StatefulWidget {
  @override
  _NewsPageState createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
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
                return InkWell(
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => VideoPlayer(data[i])));
                  },
                  child: Container(
                    key: ValueKey(data[i].title),
                    margin: EdgeInsets.all(6.0),
                    padding: EdgeInsets.only(
                      left: 2.0,
                    ),
                    constraints:
                        BoxConstraints.expand(height: 150.0, width: 150.0),
                    alignment: Alignment.bottomLeft,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(data[i].img),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(2.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: <Color>[Colors.black, Colors.white70]),
                          ),
                          child: Text(
                            data[i].title,
                            style: TextStyle(color: Colors.white),
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
                                  )
                                : Icon(
                                    Icons.star_border,
                                  )),
                      ],
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
      x.forEach((f) => data.add(NewsData.fromJson(f)));
      setState(() {});
    }
  }
}
