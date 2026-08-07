import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/services/home_screen_widget_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

/// What the location layer is doing right now, so the UI can say so.
enum LocationRefreshStatus { idle, refreshing, failed }

/// Owns *when* location is refreshed and *whether a refresh is in flight*.
///
/// The coordinates themselves still live in the `lat` / `long` / `city` globals
/// that the notification scheduler, home screen widgets and watch complication
/// all read; this sits on top and adds the three things they never modelled —
/// freshness, in-flight status, and why the last attempt failed.
///
/// Refreshing is automatic. It used to be a user-facing "always use live
/// location" switch, but the thing that setting was really protecting against
/// was the cost of a GPS fix on every single app open, and a staleness window
/// solves that without asking the user to understand the tradeoff. A location
/// younger than [freshnessWindow] is simply reused.
class LocationService extends ChangeNotifier {
  LocationService._();

  static final LocationService instance = LocationService._();

  /// How long a fix is considered good enough to reuse. Long enough that
  /// opening the app repeatedly costs nothing, short enough that a traveller
  /// gets correct prayer times shortly after arriving.
  static const Duration freshnessWindow = Duration(minutes: 30);

  /// Past this we tell the user how old the reading is, because at that point
  /// "these times might be for the wrong city" is a real possibility.
  static const Duration staleDisclosureAge = Duration(hours: 6);

  /// How long an automatic refresh backs off after a failure. A device that
  /// cannot produce a fix at all — permission denied, location services off —
  /// is permanently stale, so without this it would run a full attempt on every
  /// single resume. Successful fetches need no cooldown; [freshnessWindow]
  /// already paces those.
  static const Duration retryCooldown = Duration(minutes: 2);

  static const String updatedAtKey = 'location_updated_at';
  static const String _legacyLiveLocationKey = 'use_live_location';

  LocationRefreshStatus _status = LocationRefreshStatus.idle;
  DateTime? _updatedAt;
  DateTime? _lastUnproductiveAttemptAt;
  Future<bool>? _inFlight;

  LocationRefreshStatus get status => _status;

  bool get isRefreshing => _status == LocationRefreshStatus.refreshing;

  /// Non-null only while [status] is [LocationRefreshStatus.failed].
  LocationFailure? get failure =>
      _status == LocationRefreshStatus.failed ? lastLocationFailure : null;

  bool get hasLocation => lat != null && long != null;

  DateTime? get updatedAt => _updatedAt;

  /// Whether a fresh reading is worth fetching. No stored location always
  /// qualifies, so first run fetches immediately.
  bool get isStale {
    if (!hasLocation) return true;
    final updatedAt = _updatedAt;
    if (updatedAt == null) return true;
    return DateTime.now().difference(updatedAt) >= freshnessWindow;
  }

  /// Whether the reading is old enough that the UI should admit its age.
  bool get shouldDiscloseAge {
    final updatedAt = _updatedAt;
    if (!hasLocation || updatedAt == null) return false;
    return DateTime.now().difference(updatedAt) >= staleDisclosureAge;
  }

  /// Loads the persisted freshness stamp. Call after [SP.init] and after the
  /// `lat` / `long` / `city` globals have been restored.
  void restore() {
    if (!SP.isInitialized) return;

    final storedMillis = SP.prefs.getInt(updatedAtKey);
    if (storedMillis != null) {
      _updatedAt = DateTime.fromMillisecondsSinceEpoch(storedMillis);
    } else if (hasLocation) {
      // Upgrading from a build that never recorded this. Treat the stored fix
      // as stale so the next open refreshes it once and starts the clock.
      _updatedAt = null;
    }

    // The "always use live location" switch this service replaces.
    if (SP.prefs.containsKey(_legacyLiveLocationKey)) {
      unawaited(SP.prefs.remove(_legacyLiveLocationKey));
    }
  }

  /// Refreshes only if the current reading has aged out. Safe to call on every
  /// app open and every resume — that is the point of it.
  Future<bool> refreshIfStale({BuildContext? context}) {
    if (!isStale) {
      // The stored fix is good enough, so any error still on display is about
      // an attempt we have since decided we did not need. Clearing it stops a
      // one-off failure pinning a red message on the card for half an hour —
      // but not on top of a running fetch, whose spinner would vanish.
      if (_inFlight == null) _setStatus(LocationRefreshStatus.idle);
      return Future.value(true);
    }

    // Back off from an attempt that got us nowhere, but never while one is
    // already running: an overlapping caller should join the in-flight fetch
    // rather than be turned away.
    final lastUnproductiveAttemptAt = _lastUnproductiveAttemptAt;
    if (_inFlight == null &&
        lastUnproductiveAttemptAt != null &&
        DateTime.now().difference(lastUnproductiveAttemptAt) < retryCooldown) {
      return Future.value(hasLocation);
    }

    return refresh(context: context);
  }

  /// Fetches a new position.
  ///
  /// Concurrent callers share one fetch: app open, resume and a button tap can
  /// overlap, and running them in parallel would race on the globals and
  /// schedule notifications twice.
  ///
  /// [context] opts into the blocking diagnostic dialogs (services off,
  /// permission denied, timeout). Pass it for refreshes the user asked for;
  /// leave it null for automatic ones, where [status] carries the failure into
  /// the UI instead of interrupting them.
  Future<bool> refresh({BuildContext? context}) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    _setStatus(LocationRefreshStatus.refreshing);
    // whenComplete resolves a microtask after _run finishes, so the assignment
    // below always lands first and every overlapping caller sees this future.
    final fetch = _run(context: context).whenComplete(() => _inFlight = null);
    _inFlight = fetch;
    return fetch;
  }

  Future<bool> _run({BuildContext? context}) async {
    // First run has no stored location and no explainer shown yet, so let
    // initializeLocation walk the user through it rather than forcing.
    final isFirstEverFetch = !hasLocation;

    bool success;
    try {
      success = await initializeLocation(
        force: !isFirstEverFetch,
        context: context,
      );
    } catch (e) {
      debugPrint('Location refresh failed: $e');
      lastLocationFailure = LocationFailure.unknown;
      _lastUnproductiveAttemptAt = DateTime.now();
      _setStatus(LocationRefreshStatus.failed);
      return false;
    }

    // Deliberately outside the try above. By this point the coordinates are
    // already updated and prayer times are already correct, so a failure to
    // persist the stamp or repaint a home screen widget is not a location
    // failure and must not be reported as one.
    if (success) {
      // How old the reading is, not when we asked for it: initializeLocation
      // may have fallen back to a much older last-known position.
      _updatedAt = lastLocationFixAt ?? DateTime.now();
      try {
        if (SP.isInitialized) {
          await SP.prefs
              .setInt(updatedAtKey, _updatedAt!.millisecondsSinceEpoch);
        }
        await HomeScreenWidgetService.instance.publishAll();
      } catch (e) {
        debugPrint('Location stored, but publishing it failed: $e');
      }
    }

    // Back off from anything that left us no better off. A failure obviously
    // qualifies, but so does a success that only recovered a stale last-known
    // position: we are still stale, and without this every resume would run
    // another full attempt trying to improve on it.
    _lastUnproductiveAttemptAt = success && !isStale ? null : DateTime.now();

    _setStatus(
      success ? LocationRefreshStatus.idle : LocationRefreshStatus.failed,
    );
    return success;
  }

  void _setStatus(LocationRefreshStatus status) {
    if (_status == status) return;
    _status = status;
    notifyListeners();
  }

  /// A short reason for the most recent failure, for inline display.
  String get failureMessage {
    switch (failure) {
      case LocationFailure.serviceDisabled:
        return 'Location services are off';
      case LocationFailure.permissionDenied:
      case LocationFailure.permissionDeniedForever:
        return 'Location permission needed';
      case LocationFailure.timeout:
        return "Couldn't get a location fix";
      case LocationFailure.unknown:
      case null:
        return "Couldn't update location";
    }
  }

  @visibleForTesting
  void resetForTest() {
    _status = LocationRefreshStatus.idle;
    _updatedAt = null;
    _lastUnproductiveAttemptAt = null;
    _inFlight = null;
  }

  @visibleForTesting
  void setUpdatedAtForTest(DateTime? value) {
    _updatedAt = value;
  }
}
