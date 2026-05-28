import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shia_companion/utils/external_launch.dart';
import 'package:webview_flutter/webview_flutter.dart';

class QiblaFinder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = WebViewController()
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final externalUri = _externalUriForNavigation(request.url);
            if (externalUri == null) return NavigationDecision.navigate;

            launchExternalUri(externalUri).then((launched) {
              if (launched || !context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Unable to open link')),
              );
            });
            return NavigationDecision.prevent;
          },
        ),
      );
    if (!kIsWeb) {
      controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    }
    controller.loadRequest(Uri.parse('https://qiblafinder.withgoogle.com/'));

    return Scaffold(
      appBar: AppBar(
        title: Text("Qibla Finder"),
      ),
      body: WebViewWidget(controller: controller),
    );
  }

  Uri? _externalUriForNavigation(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return _isWhatsappShareUrl(uri) ? uri : null;
    }

    if (uri.scheme == 'intent') {
      return _intentFallbackUri(url) ?? uri;
    }

    const externalSchemes = {
      'geo',
      'mailto',
      'market',
      'sms',
      'tel',
      'whatsapp',
    };
    return externalSchemes.contains(uri.scheme) ? uri : null;
  }

  bool _isWhatsappShareUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'wa.me' ||
        host == 'api.whatsapp.com' ||
        host.endsWith('.whatsapp.com');
  }

  Uri? _intentFallbackUri(String url) {
    const fallbackKey = 'S.browser_fallback_url=';
    final start = url.indexOf(fallbackKey);
    if (start < 0) return null;

    final valueStart = start + fallbackKey.length;
    final valueEnd = url.indexOf(';', valueStart);
    final encodedFallback = url.substring(
      valueStart,
      valueEnd < 0 ? url.length : valueEnd,
    );
    return Uri.tryParse(Uri.decodeComponent(encodedFallback));
  }
}
