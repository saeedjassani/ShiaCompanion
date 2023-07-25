import 'dart:core';

class LiveStreamingData {
  String link, title;
  String? img;

  LiveStreamingData(this.link, this.title, {this.img});

  LiveStreamingData.fromJson(Map<String, dynamic> value)
      : link = value['link'],
        title = value['title'],
        img = value['img'];
}
