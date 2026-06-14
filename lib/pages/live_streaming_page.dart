import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:shia_companion/data/live_streaming_data.dart';
import 'package:shia_companion/data/universal_data.dart';
import 'package:shia_companion/widgets/responsive_content.dart';

import '../constants.dart';

class LiveStreamingPage extends StatefulWidget {
  final int arg;

  // 0 for Holy Shrines, 1 for Islamic Channels
  LiveStreamingPage(this.arg);

  @override
  _LiveStreamingPageState createState() => _LiveStreamingPageState();
}

class _LiveStreamingPageState extends State<LiveStreamingPage> {
  List<LiveStreamingData>? data;

  @override
  void initState() {
    trackScreen('Live Streaming Page');
    getData();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: getAppBar(),
      body: data != null
          ? ResponsiveContent(
              maxWidth: wideContentWidth,
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                ),
                itemCount: data!.length,
                itemBuilder: (BuildContext c, int i) {
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: InkWell(
                      onTap: () {
                        handleUniversalDataClick(
                            context, UniversalData.forLiveStream(data![i]));
                      },
                      child: Column(
                        children: [
                          Expanded(
                            child: Image.network(
                              data![i].img ?? '',
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: Icon(
                                  Icons.live_tv,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              data![i].title,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          : Center(child: CircularProgressIndicator()),
    );
  }

  void getData() async {
    String url = widget.arg == 0
        ? "https://alghazienterprises.com/sc/scripts/getHolyShrines.php"
        : "https://alghazienterprises.com/sc/scripts/getIslamicChannels.php";
    var response = await get(Uri.parse(url));
    if (response.statusCode == 200) {
      List<dynamic> x = json.decode(response.body);
      data = x.map((f) => LiveStreamingData.fromJson(f)).toList();
      setState(() {});
    }
  }
}
