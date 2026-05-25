final RegExp _uidNumberPattern = RegExp(r'\d+');

class UidTitleData {
  String uid;
  String title;

  UidTitleData(this.uid, this.title);

  // All UID must end with and integer which is used for sorting.
  // ~ in UID indicates that it is a List of Items
  // | in UID indicates that it is a duplicate Items. It's Data will be ignore and the data of the item followed by | will be processed
  String getUId() {
    return uid;
  }

  // Returns primary UID. L4 is returned when UID is G17|L4
  String getFirstUId() {
    return uid.split("|").last;
  }

  String getTitle() {
    return title;
  }

  int getId() {
    final sortableUid = uid.split("|").first;
    final match = _uidNumberPattern.firstMatch(sortableUid);
    return int.tryParse(match?.group(0) ?? '') ?? 999999;
  }
}
