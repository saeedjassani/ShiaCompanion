import 'dart:core';

class ItemData {
  String title,
      content,
      code,
      uId,
      id,
      english,
      transliteration,
      fav,
      scroll,
      audio;

  ItemData(
    this.title,
    this.content,
    this.code,
    this.uId,
    this.id,
    this.english,
    this.transliteration,
    this.fav,
    this.scroll,
    this.audio,
  );

  String getTransla() {
    return english;
  }

  void setTransla(String transla) {
    this.english = transla;
  }

  String getTransli() {
    return transliteration;
  }

  void setTransli(String transla) {
    this.transliteration = transla;
  }

  String getFav() {
    return fav;
  }

  void setFav(String fav) {
    this.fav = fav;
  }

  String getScroll() {
    return scroll;
  }

  void setScroll(String scroll) {
    this.scroll = scroll;
  }

  String getCode() {
    return code;
  }

  void setCode(String code) {
    this.code = code;
  }

  String getId() {
    return id;
  }

  void setId(String id) {
    this.id = id;
  }

  String getTitle() {
    return title;
  }

  void setTitle(String title) {
    this.title = title;
  }

  String getContent() {
    return content;
  }

  void setContent(String content) {
    this.content = content;
  }
}
