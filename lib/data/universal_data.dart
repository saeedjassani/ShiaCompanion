import 'dart:core';

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
}
