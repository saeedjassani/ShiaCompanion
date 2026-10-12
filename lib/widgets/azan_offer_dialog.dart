import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../services/analytics_service.dart';
import '../services/azaan_opt_in_service.dart';
import '../services/first_run_setup.dart';
import '../services/location_service.dart';
import 'page_chrome.dart';

bool _offering = false;

/// Puts the azan question once there is a location to time it by, for
/// someone who has not answered it yet.
///
/// First-run setup only shows its Azan step after a location is set: without
/// one there are no times to show, and switches for prayers with no time read
/// as if azan were already working. Whoever skipped that step this way is
/// asked here instead, right after they turn on location or choose a city
/// (and at launch, in case it was set some other way). Asked at most once:
/// either answer, or dismissing the dialog, counts as the answer. Not on the
/// web, which has no azan, and not during setup, which asks for itself.
Future<void> offerAzanOnceLocated(BuildContext context) async {
  if (kIsWeb || _offering) return;
  if (FirstRunSetup.isPending || AzaanOptInService.hasBeenAsked) return;
  if (!LocationService.instance.hasLocation) return;

  _offering = true;
  try {
    final l10n = context.l10n;
    final turnOn = await showRevampDialog<bool>(
      context,
      title: l10n.setupAzanTitle,
      body: l10n.azanOfferBody,
      answers: [
        DialogAnswer(true, l10n.setupTurnOnAzan, primary: true),
        DialogAnswer(false, l10n.setupNotNow),
      ],
    );
    final enable = turnOn ?? false;
    if (enable) {
      try {
        await ensureNotificationsPlugin();
      } catch (e) {
        debugPrint('Notifications could not start: $e');
      }
    }
    // Reschedules too, so the azan starts from today's times.
    await AzaanOptInService.setEnabled(enable);
    unawaited(AnalyticsService.feature(
      'azaan_opt_in',
      label: 'Azan opt-in',
      parameters: {
        'choice': enable ? 'enabled' : 'declined',
        'source': 'location_set',
      },
    ));
  } finally {
    _offering = false;
  }
}
