import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/crash_reporting.dart';

Object _forceUnwrap(Object? value) => value!;

/// A genuine null-check failure, thrown and caught for its real message and
/// runtime type - a bare `TypeError()` doesn't carry the
/// "Null check operator..." wording the VM attaches when `!` actually fires
/// on null.
Object _nullCheckError() {
  try {
    _forceUnwrap(null);
  } catch (error) {
    return error;
  }
  throw StateError('expected a null-check error');
}

/// A different, unrelated [TypeError] - a failed cast - to prove the message
/// guard actually discriminates instead of matching on type alone.
Object _castError() {
  try {
    const Object value = 1;
    return value as String;
  } catch (error) {
    return error;
  }
}

FlutterErrorDetails _detailsFor({required Object exception, required String stack}) {
  return FlutterErrorDetails(exception: exception, stack: StackTrace.fromString(stack));
}

void main() {
  group('isKnownSelectionGeometryNullCheckError', () {
    test('matches the reported _ScrollableSelectionContainerDelegate crash', () {
      final details = _detailsFor(
        exception: _nullCheckError(),
        stack: '#0  _ScrollableSelectionContainerDelegate._updateDragLocationsFromGeometries '
            '(package:flutter/src/widgets/scrollable.dart:1361)\n'
            '#1  _ScrollableSelectionContainerDelegate.handleSelectWord '
            '(package:flutter/src/widgets/scrollable.dart:1389)',
      );

      expect(isKnownSelectionGeometryNullCheckError(details), isTrue);
    });

    test('matches the sibling StaticSelectionContainerDelegate crash', () {
      final details = _detailsFor(
        exception: _nullCheckError(),
        stack: '#0  StaticSelectionContainerDelegate._updateLastSelectionEdgeLocationsFromGeometries '
            '(package:flutter/src/widgets/selectable_region.dart:2200)',
      );

      expect(isKnownSelectionGeometryNullCheckError(details), isTrue);
    });

    test('does not match a null-check error from unrelated code', () {
      final details = _detailsFor(
        exception: _nullCheckError(),
        stack: '#0  SomeWidgetState.build (package:shia_companion/pages/home_page.dart:42)',
      );

      expect(isKnownSelectionGeometryNullCheckError(details), isFalse);
    });

    test('does not match a differently-worded TypeError with a matching stack', () {
      final details = _detailsFor(
        exception: _castError(),
        stack: '#0  _ScrollableSelectionContainerDelegate._updateDragLocationsFromGeometries '
            '(package:flutter/src/widgets/scrollable.dart:1361)',
      );

      expect(isKnownSelectionGeometryNullCheckError(details), isFalse);
    });

    test('does not match a non-TypeError exception with a matching stack', () {
      final details = _detailsFor(
        exception: StateError('Null check operator used on a null value'),
        stack: '#0  _ScrollableSelectionContainerDelegate._updateDragLocationsFromGeometries '
            '(package:flutter/src/widgets/scrollable.dart:1361)',
      );

      expect(isKnownSelectionGeometryNullCheckError(details), isFalse);
    });
  });
}
