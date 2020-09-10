import 'dart:core';

class UidTitleData {
  String uid, title;

  UidTitleData(String uid, String title) {
    this.uid = uid;
    this.title = title;
  }

  // All UID must end with and integer which is used for sorting.
  // ~ in UID indicates that it is a List of Items
  // | in UID indicates that it is a duplicate Items. It's Data will be ignore and the data of the item followed by | will be processed
  String getUId() {
    return uid;
  }

  String getFirstUId() {
    if (uid.contains("|")) return uid.split("|")[1];
    return uid;
  }

  String getTitle() {
    return title;
  }

  int getId() {
    if (uid.contains("|")) {
      return int.parse(uid.split("|")[0].replaceAll(RegExp("[A-Z]*"), ""));
    }
    return int.parse(uid.replaceAll(RegExp("[A-Z]*~*[A-Z]*"), ""));
  }
}
