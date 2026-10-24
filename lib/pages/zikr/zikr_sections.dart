import 'package:flutter/foundation.dart';

import 'zikr_content_parser.dart';

/// One section heading of a zikr part - a `## ` line, see
/// [ZikrContentParser.headingMarker] - as its reader sees it.
@immutable
class ZikrSection {
  const ZikrSection({required this.lineIndex, required this.label});

  /// The heading's line in the part's parsed content.
  final int lineIndex;

  /// The heading's text, translated where a translation covers it.
  final String label;

  @override
  bool operator ==(Object other) =>
      other is ZikrSection &&
      other.lineIndex == lineIndex &&
      other.label == label;

  @override
  int get hashCode => Object.hash(lineIndex, label);
}

/// The sections of [content], in reading order. A heading whose English the
/// reader is not shown - untranslated, outside English - is left out, as the
/// heading itself is.
List<ZikrSection> zikrSectionsOf(ParsedZikrContent content) {
  final lines = content.headingLines.toList()..sort();
  return [
    for (final line in lines)
      if (!content.isHiddenEnglish(line))
        ZikrSection(
          lineIndex: line,
          label: content.displayLine(line).trim(),
        ),
  ];
}

/// The section [topLine] - the line at the top of the view - falls in: the
/// last heading at or above it. Null above the first heading.
ZikrSection? zikrSectionAt(List<ZikrSection> sections, int? topLine) {
  if (topLine == null) return null;
  ZikrSection? current;
  for (final section in sections) {
    if (section.lineIndex > topLine) break;
    current = section;
  }
  return current;
}

/// Shares the open part's sections between the reader, which parses them,
/// and the page around it, which offers the Sections menu; and carries the
/// page's pick back to the reader to scroll to.
class ZikrSectionsController extends ChangeNotifier {
  List<ZikrSection> _sections = const [];
  Future<void> Function(int lineIndex)? _jump;

  /// The sections of the part on screen; empty when it has none.
  List<ZikrSection> get sections => _sections;

  /// Called by the reader whenever the part on screen, or its text, changes.
  void setSections(List<ZikrSection> sections) {
    if (listEquals(sections, _sections)) return;
    _sections = List.unmodifiable(sections);
    notifyListeners();
  }

  /// The reader registers how it scrolls a line of the open part into view.
  void attach(Future<void> Function(int lineIndex) jump) => _jump = jump;

  void detach(Future<void> Function(int lineIndex) jump) {
    // Two tear-offs of one method are equal, not identical.
    if (_jump == jump) _jump = null;
  }

  /// Brings the heading on [lineIndex] to the top of the reader.
  Future<void> jumpTo(int lineIndex) =>
      _jump?.call(lineIndex) ?? Future.value();
}
