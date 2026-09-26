import 'dart:convert';

import 'package:flutter/services.dart';

import '../pages/zikr/zikr_content_parser.dart';
import 'quran_index.dart';
import 'quran_script.dart';

/// A readable stretch of the Quran that may run across surah boundaries.
///
/// A surah is one document in the corpus, but a juz is not - 28 of the 30 cut
/// across two or more surahs, and juz 30 across 37. Rather than teach the
/// reader to page through documents, this stitches the surahs of a portion into
/// one synthesised document of exactly the shape the reader already loads from
/// an asset: a title, a `code`, and newline-separated lines. The reader is
/// therefore unchanged, and keeps its audio, focus mode, fonts, progress and
/// sharing.
///
/// The whole portion is assembled up front. That is affordable because a juz
/// averages ~207 ayahs and the text is all in local assets; the largest, juz
/// 30, is 564.
class QuranPortion {
  const QuranPortion({
    required this.juz,
    required this.title,
    required this.data,
    required this.index,
    this.script,
  });

  final int juz;
  final String title;

  /// The stitched lines, in the reader's usual newline-separated form.
  final String data;

  /// Where every verse of the portion sits in [data], carrying the surah each
  /// belongs to and the headings between them.
  final AyahIndex index;

  /// The script every surah in [data] was swapped into, or null when [data]
  /// is the corpus text as authored.
  final QuranScript? script;

  bool get isEmpty => index.isEmpty;

  VerseKey? get firstVerse => index.verses.isEmpty ? null : index.verses.first;
  VerseKey? get lastVerse => index.verses.isEmpty ? null : index.verses.last;

  /// The reader's payload, in the same shape `_applyZikrData` takes from an
  /// asset - so a portion needs no separate loading path in the page.
  Map<String, dynamic> toZikrData() => {
        'title': title,
        'data': data,
        if (script != null) ...{
          arabicFontFamilyKey: script!.fontFamily,
          quranScriptFontKey: script!.font,
        },
      };
}

/// The identity a juz reads under.
///
/// Deliberately outside the corpus's `A`/`E`/`G` letter scheme so it can never
/// collide with a real document: a juz has no zikr of its own, and nothing must
/// try to load, favourite or edit it as one. It is only what the reader keys
/// its per-page session state by.
String quranJuzUid(int juz) => 'JUZ$juz';

/// The juz a [quranJuzUid] names, or null for any other uid.
int? juzOfQuranUid(String uid) {
  final match = RegExp(r'^JUZ(\d+)$').firstMatch(uid);
  final juz = match == null ? null : int.parse(match.group(1)!);
  return juz != null && juz >= 1 && juz <= 30 ? juz : null;
}

/// Builds juz [juz] as one continuous portion, or null if there is no such juz.
Future<QuranPortion?> loadJuzPortion(int juz, AssetBundle bundle) async {
  if (juz < 1 || juz > 30) return null;

  final part = allJuz()[juz - 1];
  final lines = <String>[];
  final spans = <AyahSpan>[];
  // Loaded once for the whole portion, so every surah in it is in the same
  // script and can be drawn in the same font.
  final script = await loadQuranScript(bundle);

  for (var surah = part.start.surah; surah <= part.end.surah; surah++) {
    final uid = uidForSurah(surah);
    if (uid == null) continue;

    final parsed = await _parseSurah(uid, surah, script, bundle);
    if (parsed == null) continue;

    // The juz covers this whole surah unless it starts or ends inside it.
    final from = surah == part.start.surah ? part.start.ayah ?? 1 : 1;
    final to = surah == part.end.surah
        ? part.end.ayah ?? ayahCountOf(surah) ?? 0
        : ayahCountOf(surah) ?? 0;

    var isFirstKept = true;
    for (final span in spansOfParsedContent(parsed, surah: surah)) {
      if (!_keeps(span, from: from, to: to)) continue;

      // The heading goes on the portion's first span from this surah, which is
      // the Bismillah when there is one and the opening verse otherwise.
      final startsSurah = isFirstKept ? surahInfoFor(surah) : null;
      isFirstKept = false;

      final offset = lines.length - span.start;
      spans.add(span.shifted(offset, startsSurah: startsSurah));
      lines.addAll(parsed.lines.sublist(span.start, span.end));
    }
  }

  return QuranPortion(
    juz: juz,
    title: 'Juz $juz',
    data: lines.join('\n'),
    index: AyahIndex.fromSpans(spans),
    script: script,
  );
}

/// Whether a surah's span belongs to the portion.
///
/// The Bismillah - the one span with no ayah number - rides along only when the
/// portion takes the surah from its first verse. A juz opening mid-surah picks
/// up the recitation partway and does not reopen with it.
bool _keeps(AyahSpan span, {required int from, required int to}) {
  final ayah = span.ayah;
  if (ayah == null) return from <= 1;
  return ayah >= from && ayah <= to;
}

Future<ParsedZikrContent?> _parseSurah(
  String uid,
  int surah,
  QuranScript? script,
  AssetBundle bundle,
) async {
  try {
    final decoded = json.decode(await bundle.loadString('assets/zikr/$uid'));
    if (decoded is! Map) return null;
    final data = decoded['data']?.toString() ?? '';

    return ZikrContentParser.parseContent(
      script == null ? data : script.apply(surah, data),
      hideHeaderLine: false,
    );
  } catch (error) {
    // A surah that will not load costs the portion that surah, not the whole
    // juz - the rest is still worth reading.
    return null;
  }
}
