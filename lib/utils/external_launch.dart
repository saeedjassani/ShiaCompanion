import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

const String supportEmailAddress = 'developer110@hotmail.com';

Future<bool> launchExternalUri(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('Unable to launch ${uri.toString()}: $error');
    return false;
  }
}

Future<bool> launchSupportEmail({String? subject}) {
  final trimmed = subject?.trim() ?? '';
  // Built by hand: Uri's queryParameters form-encodes spaces as '+', but
  // mailto: (RFC 6068) treats '+' literally, so mail apps show "A+B+C".
  return launchExternalUri(
    Uri.parse(
      trimmed.isEmpty
          ? 'mailto:$supportEmailAddress'
          : 'mailto:$supportEmailAddress?subject=${Uri.encodeComponent(trimmed)}',
    ),
  );
}
