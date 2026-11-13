import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// `find.byTooltip`, for the app's `material_ui` tooltips.
///
/// flutter_test's `find.byTooltip` matches a tooltip through the semantics of
/// the `RawTooltip` it builds, except when `excludeFromSemantics` is set (the
/// tab bar's search button, for one): those it recognises only as
/// `package:flutter/material.dart`'s `Tooltip`, a different class from
/// `material_ui`'s since Flutter 3.47, so it finds nothing. This matches
/// `material_ui`'s `Tooltip` by its message either way. Go back to
/// `find.byTooltip` once flutter_test knows `material_ui`'s `Tooltip`.
Finder findTooltip(Pattern message, {bool skipOffstage = true}) {
  return find.byWidgetPredicate((widget) {
    if (widget is! Tooltip) return false;
    final text = widget.message ?? widget.richMessage?.toPlainText() ?? '';
    return message is RegExp ? message.hasMatch(text) : text == message;
  }, skipOffstage: skipOffstage);
}
