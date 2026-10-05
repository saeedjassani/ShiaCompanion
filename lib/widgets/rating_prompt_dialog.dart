import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

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
      title: Text(context.l10n.ratingEnjoying),
      content: Text(
        context.l10n.ratingEnjoyingBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.l10n.ratingNotReally),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(context.l10n.ratingYes),
        ),
      ],
    ),
  );
}

/// Shown after a context.l10n.ratingNotReally - asks before jumping straight to the mail app,
/// since that would otherwise fire the moment someone admits they aren't
/// enjoying the app, whether or not they actually wanted to write anything.
/// Returns whether to open the feedback email.
Future<bool> showRatingFeedbackDialog(BuildContext context) async {
  final sendFeedback = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.ratingSorry),
      content: Text(
        context.l10n.ratingSorryBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.l10n.ratingNoThanks),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(context.l10n.ratingSendFeedback),
        ),
      ],
    ),
  );
  return sendFeedback ?? false;
}
