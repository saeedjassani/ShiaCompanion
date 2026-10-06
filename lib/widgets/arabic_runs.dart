import 'package:flutter/widgets.dart';

import '../constants.dart';

/// Arabic script, as titles use it: letters, harakat and presentation forms.
const String arabicScript = r'؀-ۿݐ-ݿࢠ-ࣿ'
    r'ﭐ-﷿ﹰ-﻿';

/// A run of Arabic words, with the spaces and joiners between them:
/// "الحمد لله" in "Ziyarat Rajabiyah (الحمد لله …)".
final RegExp _arabicRun = RegExp(
  '[$arabicScript]+(?:[\\s\\u200C\\u200D.…]+[$arabicScript]+)*',
);

/// [text] as spans, with each run of Arabic in the reader's Arabic font and
/// the rest left to the UI font. Every span carries [style] (a search
/// match's bold); `null` when [text] holds no Arabic, so callers can keep a
/// plain string.
List<TextSpan>? arabicRunSpans(String text, {TextStyle? style}) {
  final matches = _arabicRun.allMatches(text).toList();
  if (matches.isEmpty) return null;

  // Only on the Arabic: Qalam in a whole line's fallback list takes over
  // the English too wherever the UI font ahead of it is not a registered
  // font (Qalam has Latin letters).
  final arabic = (style ?? const TextStyle()).copyWith(
    fontFamily: arabicFont,
    fontFamilyFallback: const ['Qalam'],
  );
  final spans = <TextSpan>[];
  var start = 0;
  for (final match in matches) {
    if (match.start > start) {
      spans.add(
          TextSpan(text: text.substring(start, match.start), style: style));
    }
    spans.add(TextSpan(text: match.group(0), style: arabic));
    start = match.end;
  }
  if (start < text.length) {
    spans.add(TextSpan(text: text.substring(start), style: style));
  }
  return spans;
}

/// [text] with its Arabic in the reader's Arabic font (see
/// [arabicRunSpans]); a plain [Text] when it has none.
Text textWithArabicRuns(String text, {TextStyle? style}) {
  final spans = arabicRunSpans(text);
  if (spans == null) return Text(text, style: style);
  return Text.rich(TextSpan(children: spans),
      style: style, semanticsLabel: text);
}
