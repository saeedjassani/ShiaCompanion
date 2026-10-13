import 'package:flutter/widgets.dart';

import '../constants.dart';
import '../l10n/app_language.dart';
import '../l10n/l10n.dart';
import '../services/zikr_translations.dart';

/// Arabic script, as titles use it: letters, harakat and presentation forms.
const String arabicScript = r'؀-ۿݐ-ݿࢠ-ࣿ'
    r'ﭐ-﷿ﹰ-﻿';

/// A run of Arabic words, with the spaces and joiners between them:
/// "الحمد لله" in "Ziyarat Rajabiyah (الحمد لله …)".
final RegExp _arabicRun = RegExp(
  '[$arabicScript]+(?:[\\s\\u200C\\u200D.…]+[$arabicScript]+)*',
);

/// Whether a title's Arabic is set in the reader's Arabic font: only while
/// neither the app nor the zikr titles are in Urdu, Persian or Arabic.
///
/// In those languages every Arabic-script letter of a menu or a title is
/// the language's own text - "۲: البقرة", "آیت محفوظ کریں" - and belongs in
/// the app's font (the system font, or the Urdu font). Qalam and
/// Scheherazade are for the Arabic of the zikrs themselves; in Qalam a
/// title's ٢ or ۲ is not drawn at all.
bool get arabicFontForTitles {
  bool arabicScript(String code) => appLanguageFor(code)?.isRtl ?? false;
  return !arabicScript(L10n.current.localeName) &&
      !arabicScript(ZikrTranslations.instance.language.code);
}

/// [text] as spans, with each run of Arabic in the reader's Arabic font and
/// the rest left to the UI font. Every span carries [style] (a search
/// match's bold); `null` when [text] holds no Arabic, or when the app is in
/// a language written in Arabic script ([arabicFontForTitles]), so callers
/// can keep a plain string.
List<TextSpan>? arabicRunSpans(String text, {TextStyle? style}) {
  if (!arabicFontForTitles) return null;
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
Text textWithArabicRuns(String text,
    {TextStyle? style, int? maxLines, TextOverflow? overflow}) {
  final spans = arabicRunSpans(text);
  if (spans == null) {
    return Text(text, style: style, maxLines: maxLines, overflow: overflow);
  }
  return Text.rich(TextSpan(children: spans),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      semanticsLabel: text);
}
