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
      String title,
      String content,
      String code,
      String uId,
      String id,
      String english,
      String transliteration,
      String fav,
      String scroll,
      String audio) {
    this.title = title;
    this.content = content;
    this.code = code;
    this.uId = uId;
    this.id = id;
    this.english = english;
    this.transliteration = transliteration;
    this.fav = fav;
    this.scroll = scroll;
    this.audio = audio;
  }

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
