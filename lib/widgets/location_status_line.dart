import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../constants.dart';
import '../l10n/l10n.dart';
import '../services/analytics_service.dart';
import '../services/location_service.dart';
import '../theme/shia_colors.dart';
import 'outline_icon.dart';

/// The one tap that brings an old location up to date, chosen by why the
/// last refresh failed.
enum LocationStatusAction { allow, openSettings, turnOn, tryAgain, update }

/// What to say about a location that is a day or more old
/// ([LocationService.shouldDiscloseAge]): its age, why it has not been
/// updated if a refresh failed, and the fix. Null when there is nothing worth
/// saying - a fresh reading, a refresh still running, a city the reader chose
/// (it never ages), or no location at all (the prayer card asks for one).
class LocationStatus {
  const LocationStatus({required this.message, required this.action});

  final String message;
  final LocationStatusAction action;

  static LocationStatus? of(LocationService location) {
    final updatedAt = location.updatedAt;
    if (updatedAt == null ||
        location.isRefreshing ||
        !location.shouldDiscloseAge) {
      return null;
    }
    final l10n = L10n.current;
    final days = math.max(1, DateTime.now().difference(updatedAt).inDays);
    final failure = location.failure;
    if (failure == null) {
      return LocationStatus(
        message: l10n.locationFromDaysAgo(days),
        action: LocationStatusAction.update,
      );
    }
    final action = switch (failure) {
      LocationFailure.permissionDenied => LocationStatusAction.allow,
      // Neither settings screen can be opened from a browser.
      LocationFailure.permissionDeniedForever => kIsWeb
          ? LocationStatusAction.tryAgain
          : LocationStatusAction.openSettings,
      LocationFailure.serviceDisabled =>
        kIsWeb ? LocationStatusAction.tryAgain : LocationStatusAction.turnOn,
      LocationFailure.timeout ||
      LocationFailure.unknown =>
        LocationStatusAction.tryAgain,
    };
    return LocationStatus(
      message: '${location.failureMessage} · ${l10n.locationAgeDays(days)}',
      action: action,
    );
  }
}

/// Under the city button on Home and the Calendar: one line saying the
/// location is old and why, with the button that fixes it. Draws nothing
/// while [LocationStatus.of] has nothing to say, so it can sit in a layout
/// unconditionally.
class LocationStatusLine extends StatefulWidget {
  const LocationStatusLine({
    super.key,
    this.alignment = MainAxisAlignment.start,
    this.padding = const EdgeInsets.only(top: 6),
  });

  /// Lines it up with the city button above it.
  final MainAxisAlignment alignment;

  /// Around the line, only while it shows.
  final EdgeInsetsGeometry padding;

  @override
  State<LocationStatusLine> createState() => _LocationStatusLineState();
}

class _LocationStatusLineState extends State<LocationStatusLine> {
  final LocationService _location = LocationService.instance;
  late final AppLifecycleListener _lifecycle;

  /// Set while the reader is in the phone's settings at our request. Coming
  /// back retries straight away: the automatic resume refresh may still be in
  /// its cooldown from the failure that sent them there.
  bool _awaitingSettings = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onResume() {
    if (!_awaitingSettings) return;
    _awaitingSettings = false;
    unawaited(_location.refresh());
  }

  Future<void> _act(LocationStatusAction action) async {
    unawaited(AnalyticsService.feature(
      'location_status_action',
      label: 'Location status action',
      parameters: {'action': action.name},
    ));
    switch (action) {
      case LocationStatusAction.openSettings:
        _awaitingSettings = true;
        await Geolocator.openAppSettings();
      case LocationStatusAction.turnOn:
        _awaitingSettings = true;
        await Geolocator.openLocationSettings();
      case LocationStatusAction.allow:
      case LocationStatusAction.tryAgain:
      case LocationStatusAction.update:
        // An explicit tap, so the permission prompt and the dialogs that
        // explain a failure are welcome here.
        await _location.refresh(context: context);
    }
  }

  String _actionLabel(LocationStatusAction action) {
    final l10n = context.l10n;
    return switch (action) {
      LocationStatusAction.allow => l10n.locationActionAllow,
      LocationStatusAction.openSettings => l10n.commonOpenSettings,
      LocationStatusAction.turnOn => l10n.locationActionTurnOn,
      LocationStatusAction.tryAgain => l10n.commonTryAgain,
      LocationStatusAction.update => l10n.locationActionUpdate,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _location,
      builder: (context, _) {
        final status = LocationStatus.of(_location);
        if (status == null) return const SizedBox.shrink();
        final colors = ShiaColors.of(context);
        return Padding(
          padding: widget.padding,
          child: Row(
            mainAxisAlignment: widget.alignment,
            children: [
              OutlineIcon(
                OutlineGlyph.alert,
                size: 14,
                color: colors.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  status.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ShiaText.caption.copyWith(color: colors.textMuted),
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () => _act(status.action),
                style: TextButton.styleFrom(
                  foregroundColor: colors.accent,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  // On the theme's label style, not instead of it: a button's
                  // text style replaces what it inherits, and with it the
                  // Scheherazade fallback Urdu, Persian and Arabic need.
                  textStyle: Theme.of(context).textTheme.labelLarge?.merge(
                        ShiaText.caption.copyWith(fontWeight: FontWeight.w700),
                      ),
                ),
                child: Text(_actionLabel(status.action)),
              ),
            ],
          ),
        );
      },
    );
  }
}
