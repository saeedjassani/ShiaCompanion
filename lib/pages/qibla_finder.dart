import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class QiblaFinder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse('https://qiblafinder.withgoogle.com/'));

    return Scaffold(
      appBar: AppBar(
        title: Text("Qibla Finder"),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
