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
      icon: const Icon(Icons.favorite_border),
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
