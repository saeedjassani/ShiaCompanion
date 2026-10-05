import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

/// The dialog's body text. iOS gets an extra line because its notifications
/// can only carry a short clip, so the full azan is not what plays by default.
String azaanOptInMessage({required bool isIOS}) {
  final l10n = L10n.current;
  return [
    l10n.azaanOptInIntro,
    if (isIOS) l10n.azaanOptInIosNote,
    l10n.azaanOptInChangeLater,
  ].join('\n\n');
}

/// Asks whether the app may notify the user at prayer times and play the azan.
///
/// Returns true when the user opts in. Not dismissible by tapping outside: the
/// answer is recorded either way and the question is only asked once, so a
/// stray tap must not count as a decision.
Future<bool> showAzaanOptInDialog(BuildContext context) async {
  final enabled = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        icon: const Icon(Icons.volume_up),
        title: Text(L10n.current.azaanOptInTitle),
        content: Text(azaanOptInMessage(isIOS: !kIsWeb && Platform.isIOS)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L10n.current.azaanOptInNotNow),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L10n.current.azaanOptInEnable),
          ),
        ],
      );
    },
  );

  // A dismissal that got past the barrier — a back gesture, the route being
  // torn down — is not consent.
  return enabled ?? false;
}
