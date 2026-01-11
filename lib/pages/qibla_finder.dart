import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class QiblaFinder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = WebViewController()
      ..loadRequest(Uri.parse('https://qiblafinder.withgoogle.com/'));
    if (!kIsWeb) {
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Qibla Finder"),
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
