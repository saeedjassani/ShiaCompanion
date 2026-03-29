import 'dart:core';

import 'package:shia_companion/data/live_streaming_data.dart';
import 'package:shia_companion/data/uid_title_data.dart';

/*  Used to store favorites, deep links, etc.
    Type 0: Zikr Data
    Type 1: Library Data
    Type 2: Holy Shrines/Islamic Channels (navigation only)
*/

class UniversalData {
  String uid, title;
  int type;

  UniversalData(this.uid, this.title, this.type);

  String get canonicalUid {
    final normalizedUid = uid.trim();
    if (type != 0) return normalizedUid;
    return UidTitleData(normalizedUid, title).getFirstUId().trim();
  }

  String get favoriteKey => '$type:$canonicalUid';

  @override
  bool operator ==(other) {
    return (other is UniversalData) &&
        other.canonicalUid == canonicalUid &&
        other.type == type;
  }

  @override
  int get hashCode => canonicalUid.hashCode ^ type.hashCode;

  Map toJson() {
    return {'title': title, 'type': type, 'uid': canonicalUid};
  }

  static UniversalData forUidTitleData(UidTitleData data) {
    return UniversalData(data.uid, data.title, 0);
  }

  static UniversalData forLiveStream(LiveStreamingData data) {
    return UniversalData(data.link, data.title, 2);
  }
}
