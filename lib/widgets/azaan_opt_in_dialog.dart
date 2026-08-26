import 'package:flutter/material.dart';

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
        title: const Text('Play the azan at prayer times?'),
        content: const Text(
          'Shia Companion can send you a notification at Fajr, Zuhr and '
          'Maghrib and play the azan.\n\n'
          'You can change which prayers notify you, pick a different sound, or '
          'turn this off again at any time in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enable azan'),
          ),
        ],
      );
    },
  );

  // A dismissal that got past the barrier — a back gesture, the route being
  // torn down — is not consent.
  return enabled ?? false;
}
