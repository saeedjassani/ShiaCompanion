import 'package:flutter/foundation.dart';

/// Whether [details] is the known, still-open Flutter framework race where a
/// [SelectionArea] sits above a `Scrollable` (as the zikr reading column
/// does, to let a selection span multiple lines and auto-scroll while a
/// handle is dragged past the edge).
///
/// The framework force-unwraps a selection's start/end point right after
/// asserting the selection exists, and the two can disagree - the point
/// hasn't been computed yet for a selectable that scrolled into place, or has
/// just been disposed - which throws this null-check `TypeError` from deep in
/// `_ScrollableSelectionContainerDelegate`/`StaticSelectionContainerDelegate`.
/// It reproduces from several different gestures (long-press word selection,
/// select-all, drag-extend), so no single call site can be hardened against
/// it from app code: flutter/flutter#119355, #123378, #124078; a framework
/// fix is proposed but unreleased in flutter/flutter#192468.
///
/// Reported non-fatal instead of fatal so the crash doesn't take the app
/// down - the gesture that hit it just fails to extend the selection - while
/// still surfacing in Crashlytics so a regression in its rate is visible.
bool isKnownSelectionGeometryNullCheckError(FlutterErrorDetails details) {
  if (details.exception is! TypeError) return false;
  if (!details.exceptionAsString().contains('Null check operator')) {
    return false;
  }

  final stack = details.stack?.toString().toLowerCase() ?? '';
  return stack.contains('selectioncontainerdelegate') &&
      stack.contains('geometries');
}
