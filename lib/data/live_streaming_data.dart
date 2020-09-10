import 'dart:core';

class LiveStreamingData {
  String link, title, img;

  LiveStreamingData(String uid, String title, String img) {
    this.link = uid;
    this.title = title;
  }

  LiveStreamingData.fromJson(var value) {
    this.title = value['title'];
    this.link = value['link'];
    this.img = value['img'];
  }
}
