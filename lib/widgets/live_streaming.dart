import 'package:flutter/material.dart';
import 'package:shia_companion/data/live_streaming_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/pages/video_player.dart';
import '../constants.dart';

class LiveStreaming extends StatefulWidget {
  final List<LiveStreamingData> data;

  LiveStreaming(this.data);

  @override
  _LiveStreamingState createState() => new _LiveStreamingState();
}

class _LiveStreamingState extends State<LiveStreaming> {
  _LiveStreamingState();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    List<LiveStreamingData> data = widget.data;
    return SizedBox(
      height: 120,
      width: screenWidth,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 0.0, 8.0),
        child: Card(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: data.length,
            itemBuilder: (BuildContext c, int i) {
              return InkWell(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => VideoPlayer(data[i])));
                },
                onLongPress: () {
                  UniversalData universalData =
                      UniversalData(data[i].link, data[i].title, 2);
                  if (favsData.contains(universalData)) {
                    favsData.remove(universalData);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Removed from favorites"),
                    ));
                  } else {
                    favsData.add(universalData);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text("Added to favorites"),
                    ));
                  }
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
                  child: Container(
                    width: screenWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: <Color>[Colors.black, Colors.white70]),
                    ),
                    child: Text(
                      data[i].title,
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
