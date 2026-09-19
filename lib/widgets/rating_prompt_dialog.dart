import 'package:flutter/material.dart';

/// Asks whether the app is working out before ever showing the OS review
/// sheet - a "yes" here is what earns the native prompt, a "no" is routed to
/// feedback instead, so an unhappy moment never turns into a public bad
/// rating.
///
/// Dismissible by tapping outside or the back gesture, unlike the azan
/// opt-in: this is a low-stakes, skippable question, not a permission that
/// needs a real answer. A dismissal comes back as `null` and is treated the
/// same as "not now".
Future<bool?> showRatingPromptDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Enjoying Shia Companion?'),
      content: const Text(
        "We'd love to hear how it's going for you - your feedback helps us "
        'keep improving the app.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Not really'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Yes!'),
        ),
      ],
    ),
  );
}

/// Shown after a "Not really" - asks before jumping straight to the mail app,
/// since that would otherwise fire the moment someone admits they aren't
/// enjoying the app, whether or not they actually wanted to write anything.
/// Returns whether to open the feedback email.
Future<bool> showRatingFeedbackDialog(BuildContext context) async {
  final sendFeedback = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Sorry to hear that'),
      content: const Text(
        "Would you mind telling us what's not working? It helps us improve "
        'the app.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('No thanks'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Send feedback'),
        ),
      ],
    ),
  );
  return sendFeedback ?? false;
}
