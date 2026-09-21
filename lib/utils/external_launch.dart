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

Future<bool> launchSupportEmail({String? subject, String? body}) {
  final queryParameters = <String, String>{
    if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
    if (body != null && body.trim().isNotEmpty) 'body': body,
  };
  return launchExternalUri(
    Uri(
      scheme: 'mailto',
      path: supportEmailAddress,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    ),
  );
}
