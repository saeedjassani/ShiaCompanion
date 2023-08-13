import 'dart:core';

import 'package:shia_companion/data/live_streaming_data.dart';
import 'package:shia_companion/data/uid_title_data.dart';

/*  Used to store favorites, deep links, etc.
    Type 0: Zikr Data
    Type 1: Library Data
    Type 2: Holy Shrines/Islamic Channels 
*/

class UniversalData {
  String uid, title;
  int type;

  UniversalData(this.uid, this.title, this.type);

  @override
  bool operator ==(other) {
    return (other is UniversalData) &&
        other.uid == uid &&
        other.title == title &&
        other.type == type;
  }

  @override
  int get hashCode => uid.hashCode ^ title.hashCode ^ type.hashCode;

  Map toJson() {
    return {'title': title, 'type': type, 'uid': uid};
  }

  static UniversalData forUidTitleData(UidTitleData data) {
    return UniversalData(data.uid, data.title, 0);
  }

  static UniversalData forLiveStream(LiveStreamingData data) {
    return UniversalData(data.link, data.title, 2);
  }
}
