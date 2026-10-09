import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import 'page_chrome.dart';

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
  final l10n = context.l10n;
  return showRevampDialog<bool>(
    context,
    title: l10n.ratingEnjoying,
    body: l10n.ratingEnjoyingBody,
    answers: [
      DialogAnswer(true, l10n.ratingYes, primary: true),
      DialogAnswer(false, l10n.ratingNotReally),
    ],
  );
}

/// Shown after a "Not really" - asks before jumping straight to the mail app,
/// since that would otherwise fire the moment someone admits they aren't
/// enjoying the app, whether or not they actually wanted to write anything.
/// Returns whether to open the feedback email.
Future<bool> showRatingFeedbackDialog(BuildContext context) async {
  final l10n = context.l10n;
  final sendFeedback = await showRevampDialog<bool>(
    context,
    title: l10n.ratingSorry,
    body: l10n.ratingSorryBody,
    answers: [
      DialogAnswer(true, l10n.ratingSendFeedback, primary: true),
      DialogAnswer(false, l10n.ratingNoThanks),
    ],
  );
  return sendFeedback ?? false;
}
