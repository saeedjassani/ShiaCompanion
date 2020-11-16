import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:shia_companion/data/live_streaming_data.dart';
import 'package:video_player/video_player.dart';

class CVideoPlayer extends StatefulWidget {
  final LiveStreamingData url;

  CVideoPlayer(this.url);

  @override
  _CVideoPlayerState createState() => new _CVideoPlayerState();
}

class _CVideoPlayerState extends State<CVideoPlayer> {
  _CVideoPlayerState();
  VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    _controller = VideoPlayerController.network(
        widget.url.link.replaceAll("http:", "https:"))
      ..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    // widget.url = "http://cdn.smartstream.video/smartstream-us/channelwinlive/channelwinlive/playlist.m3u8";
    if (widget.url.link.contains("/")) {
      return Scaffold(
          appBar: Platform.isIOS
              ? AppBar(
                  title: Text(widget.url.title),
                )
              : null,
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              });
            },
            child: Icon(
              _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
            ),
          ),
          body: Center(
            child: _controller.value.initialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  )
                : Container(),
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
    _controller.dispose();
    super.dispose();
  }
}
