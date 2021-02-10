import 'package:flutter/material.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';

class QiblaFinder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return WebviewScaffold(
        appBar: AppBar(
          title: Text("Qibla Finder"),
        ),
        url: "https://qiblafinder.withgoogle.com/");
  }
}
