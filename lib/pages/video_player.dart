import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:shia_companion/data/live_streaming_data.dart';

import '../constants.dart';

class VideoPlayer extends StatefulWidget {
  final LiveStreamingData url;

  VideoPlayer(this.url);

  @override
  _VideoPlayerState createState() => new _VideoPlayerState();
}

class _VideoPlayerState extends State<VideoPlayer> {
  _VideoPlayerState();

  @override
  void initState() {
    super.initState();
    trackScreen('Video Player Page');
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    // widget.url = "http://cdn.smartstream.video/smartstream-us/channelwinlive/channelwinlive/playlist.m3u8";
    if (widget.url.link.contains("/")) {
      return Scaffold(
          appBar: Platform.isIOS ? getAppBar() : null,
          body: WebviewScaffold(
            url: widget.url.link,
          ));
    } else {
      return Scaffold(
          appBar: Platform.isIOS
              ? AppBar(
                  title: Text(widget.url.title),
                )
              : null,
          body: WebviewScaffold(
              url: new Uri.dataFromString(
                      '<iframe src="http://www.youtube.com/embed/${widget.url.link}?autoplay=1&controls=0&rel=0" style="position:fixed; top:0px; left:0px; bottom:0px; right:0px; width:100%; height:100%; border:none; margin:0; padding:0; overflow:hidden; z-index:999999;"  frameborder="0" allowfullscreen></iframe>',
                      mimeType: 'text/html')
                  .toString()));
    }
  }

  @override
  dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }
}
