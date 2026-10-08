import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/l10n/app_language.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';
import 'package:shia_companion/pages/zikr/zikr_form_helpers.dart';
import 'package:shia_companion/services/zikr_translations.dart';
import 'package:yaml/yaml.dart';

/// Serves [files] as assets, with an AssetManifest.bin listing them - all
/// [ZikrTranslations] needs to discover languages and load them.
class _FakeBundle extends CachingAssetBundle {
  _FakeBundle(this.files);

  final Map<String, String> files;

  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(<Object?, Object?>{
        for (final path in files.keys)
          path: <Object?>[
            <Object?, Object?>{'asset': path},
          ],
      })!;
    }
    final content = files[key];
    if (content == null) throw FlutterError('Unable to load asset: $key');
    return ByteData.sublistView(utf8.encode(content));
  }
}

const _urdu = AppLanguage(
  code: 'ur',
  englishName: 'Urdu',
  nativeName: 'اردو',
  isRtl: true,
);

// Arabic / transliteration / translation, plus a standalone instruction.
// Segments: 0 the instruction, 1 and 2 the verses.
const _content = 'Say the following:\n'
    'اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ\n'
    'ALLAAHUMMA SALLE A’LAA MOHAMMADIN\n'
    'O Allah, bless Muhammad\n'
    'اَللّٰهُمَّ اغْفِرْ لِيْ\n'
    'ALLAAHUMMAGH FIR LEE\n'
    'O Allah, forgive me';

/// A segment's fingerprint, as scripts/zikr_i18n/zikr_i18n.py's anchor()
/// computes it for scripts/zikr_i18n/segment_anchors.json.
String _anchor(String? text) {
  if (text == null) return 'h:';
  if (ZikrContentParser.isArabic(text)) {
    const fold = {
      'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ؤ': 'و', 'ئ': 'ي', 'ى': 'ي', //
      'ی': 'ي', 'ے': 'ي', 'ې': 'ي', 'ک': 'ك', 'ہ': 'ه', 'ھ': 'ه', 'ة': 'ه',
      'ۃ': 'ه', 'ۀ': 'ه', 'ء': '',
    };
    final out = StringBuffer();
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final folded = fold[ch] ?? ch;
      if (folded.isEmpty) continue;
      final code = folded.runes.first;
      if ((code >= 0x0621 && code <= 0x063A) ||
          (code >= 0x0641 && code <= 0x064A) ||
          (code >= 0x0671 && code <= 0x06D3)) {
        out.write(folded);
      }
    }
    final letters = out.toString().runes.take(32);
    return 'a:${String.fromCharCodes(letters)}';
  }
  final letters = text.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  return 'e:${letters.length > 32 ? letters.substring(0, 32) : letters}';
}

/// Every segment of zikr content [document] as the reader numbers them:
/// (fingerprint, whether a translation has somewhere to go).
List<(String, bool)> _segmentsOf(Map<String, dynamic> document) {
  final rawTabs = document['tabs'];
  final tabs = buildVisibleZikrTabContents(
    primary: document['data']?.toString() ?? '',
    extraTabs: rawTabs is List
        ? rawTabs.map((tab) => tab?.toString() ?? '')
        : const <String>[],
  );
  final hasHeaders = tabs.length > 1;
  final segments = <(String, bool)>[];
  for (final tab in tabs) {
    if (hasHeaders) {
      final header = ZikrContentParser.tabHeaderLine(tab);
      segments.add((
        _anchor(header),
        header != null && !ZikrContentParser.isArabic(header),
      ));
    }
    final parsed =
        ZikrContentParser.parseContent(tab, hideHeaderLine: hasHeaders);
    for (final segment in parsed.segments) {
      segments.add((
        _anchor(parsed.lines[segment.anchorLine]),
        segment.slotLine != null
      ));
    }
  }
  return segments;
}

void main() {
  group('ParsedZikrContent.segments', () {
    final parsed =
        ZikrContentParser.parseContent(_content, hideHeaderLine: false);

    test('numbers standalone lines and verses, not their English', () {
      expect(parsed.segments.map((s) => s.anchorLine), [0, 1, 4]);
      expect(parsed.segments.map((s) => s.slotLine), [0, 3, 6]);
    });

    test('a verse with no translation line has nowhere to put one', () {
      final bare = ZikrContentParser.parseContent(
        'اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ\n'
        'اَللّٰهُمَّ اغْفِرْ لِيْ',
        hideHeaderLine: false,
      );
      expect(bare.segments.map((s) => s.slotLine), [isNull, isNull]);
    });

    test('tabs are numbered on from each other, each label first', () {
      const second = 'Part two\nO Allah\nO Allah, have mercy';
      expect(ZikrContentParser.segmentOffsets([_content]), [0]);
      // Tab one: its label, then the instruction and two verses (the label
      // line itself is hidden from the content); tab two follows on.
      expect(ZikrContentParser.segmentOffsets([_content, second]), [0, 3]);
    });
  });

  group('ParsedZikrContent.localizedTo', () {
    final parsed =
        ZikrContentParser.parseContent(_content, hideHeaderLine: false);
    const translation = ZikrDocumentTranslation(
      language: _urdu,
      segments: {
        0: 'یہ پڑھیں:',
        1: 'اے اللہ، محمد پر رحمت نازل فرما',
      },
    );

    test('lays each segment over its line', () {
      final urdu = parsed.localizedTo(_urdu, translation, firstSegment: 0);
      expect(urdu.displayLine(0), 'یہ پڑھیں:');
      expect(urdu.displayLine(3), 'اے اللہ، محمد پر رحمت نازل فرما');
      expect(urdu.directionOf(3), TextDirection.rtl);
      expect(urdu.directionOf(1), TextDirection.rtl); // Arabic
    });

    test('hides the English nobody has translated', () {
      final urdu = parsed.localizedTo(_urdu, translation, firstSegment: 0);
      expect(urdu.isHiddenEnglish(6), isTrue); // 'O Allah, forgive me'
      expect(urdu.isHiddenEnglish(2), isTrue); // transliteration
      expect(urdu.isHiddenEnglish(3), isFalse);
      expect(urdu.isHiddenEnglish(1), isFalse); // Arabic

      // With nothing translated at all, the reader sees the Arabic alone.
      final bare = parsed.localizedTo(_urdu, null, firstSegment: 0);
      for (var i = 0; i < parsed.lines.length; i++) {
        expect(bare.isHiddenEnglish(i), !parsed.arabicCodes.contains(i),
            reason: parsed.lines[i]);
      }
    });

    test('counts from the tab’s first segment', () {
      final urdu = parsed.localizedTo(_urdu, translation, firstSegment: 1);
      // Segment 1 is now the instruction; 2, the first verse, has nothing.
      expect(urdu.displayLine(0), 'اے اللہ، محمد پر رحمت نازل فرما');
      expect(urdu.isHiddenEnglish(3), isTrue);
    });

    test('keeps the English lines and the parse they produced', () {
      final urdu = parsed.localizedTo(_urdu, translation, firstSegment: 0);
      // Urdu is in Arabic script; were it re-parsed it would count as a
      // verse. Bookmarks and verse matching key off these.
      expect(urdu.lines, parsed.lines);
      expect(urdu.arabicCodes, parsed.arabicCodes);
      expect(urdu.transliCodes, parsed.transliCodes);
      expect(urdu.translaCodes, parsed.translaCodes);
    });

    test('is a no-op in English', () {
      expect(
        identical(
            parsed.localizedTo(englishLanguage, null, firstSegment: 0), parsed),
        isTrue,
      );
    });
  });

  group('ZikrContentParser.localizedTabHeader', () {
    const tab = 'Part two\nO Allah';
    const translation = ZikrDocumentTranslation(
      language: _urdu,
      segments: {3: 'دوسرا حصہ'},
    );

    test('is the first line in English', () {
      expect(
        ZikrContentParser.localizedTabHeader(tab, 1,
            offsets: const [], language: englishLanguage),
        'Part two',
      );
    });

    test('is the translation, an Arabic label, or nothing', () {
      expect(
        ZikrContentParser.localizedTabHeader(tab, 1,
            offsets: const [0, 3], language: _urdu, translation: translation),
        'دوسرا حصہ',
      );
      expect(
        ZikrContentParser.localizedTabHeader(tab, 1,
            offsets: const [0, 4], language: _urdu, translation: translation),
        isNull,
      );
      expect(
        ZikrContentParser.localizedTabHeader('زيارة\nO Allah', 0,
            offsets: const [0], language: _urdu),
        'زيارة',
      );
    });
  });

  group('the reader', () {
    final translations = ZikrTranslations.instance;
    final bundle = _FakeBundle({
      'assets/zikr_i18n/ur/index.json': jsonEncode({'titles': {}}),
    });

    setUp(() {
      translations.debugReset();
      showTranslation = true;
      showTransliteration = true;
      showArabicAsParagraph = false;
    });
    tearDown(translations.debugReset);

    Future<void> pumpViewer(
      WidgetTester tester,
      ZikrDocumentTranslation? translation,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZikrContentViewerWidget(
            tabContents: const [_content],
            selectedTabIndex: 0,
            onTabChanged: (_) {},
            hasMerits: false,
            onShowMerits: () {},
            onLinkTap: (_) async {},
            translation: translation,
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('reads in Urdu: translations, the Arabic, and no English',
        (tester) async {
      await tester.runAsync(() => translations.setLanguage('ur', bundle));
      await pumpViewer(
        tester,
        const ZikrDocumentTranslation(
          language: _urdu,
          segments: {
            0: 'یہ پڑھیں:',
            1: 'اے اللہ، محمد پر رحمت نازل فرما',
          },
        ),
      );

      final urdu =
          find.text('اے اللہ، محمد پر رحمت نازل فرما', findRichText: true);
      expect(urdu, findsOneWidget);
      expect(tester.widget<RichText>(urdu).textDirection, TextDirection.rtl);

      // The instruction box takes the translation's direction too.
      final instruction = find.text('یہ پڑھیں:', findRichText: true);
      expect(instruction, findsOneWidget);
      expect(
        Directionality.of(tester.element(instruction)),
        TextDirection.rtl,
      );

      // No English: not the lines the translation replaced, not the verse
      // nobody has translated yet, not the transliteration.
      for (final english in [
        'O Allah, bless Muhammad',
        'Say the following:',
        'O Allah, forgive me',
        'ALLAAHUMMA SALLE A’LAA MOHAMMADIN',
        'ALLAAHUMMAGH FIR LEE',
      ]) {
        expect(find.text(english, findRichText: true), findsNothing,
            reason: english);
      }
      // Both verses' Arabic is still there.
      expect(
          find.textContaining('اغْفِرْ', findRichText: true), findsOneWidget);
    });

    testWidgets('shows the English and transliteration in English',
        (tester) async {
      await pumpViewer(tester, null);
      expect(find.text('O Allah, bless Muhammad', findRichText: true),
          findsOneWidget);
      expect(
          find.text('Say the following:', findRichText: true), findsOneWidget);
      expect(find.text('ALLAAHUMMA SALLE A’LAA MOHAMMADIN', findRichText: true),
          findsOneWidget);
    });
  });

  group('ZikrTranslations', () {
    final translations = ZikrTranslations.instance;

    final bundle = _FakeBundle({
      'assets/zikr_i18n/ur/index.json': jsonEncode({
        'titles': {'E1': 'دعائے کمیل', 'G17|L4': ''},
        'audio': {
          'labels': {'quran/surah-001.mp3': 'سورہ فاتحہ'},
          'reciters': {'Ali Fani': 'علی فانی'},
        },
      }),
      'assets/zikr_i18n/ur/E1.json': jsonEncode({
        'merits': 'فضیلت',
        'segments': {'0': 'اے اللہ', '1': '', 'x': 'ignored'},
      }),
    });

    setUp(translations.debugReset);
    tearDown(translations.debugReset);

    test('discovers languages from the bundle', () async {
      expect(await translations.availableLanguageCodes(bundle), {'en', 'ur'});
      translations.debugReset();
      expect(
        await translations.availableLanguageCodes(_FakeBundle({})),
        {'en'},
      );
    });

    test('loads titles and documents for the chosen language', () async {
      await translations.setLanguage('ur', bundle);

      expect(translations.language.code, 'ur');
      expect(translations.titleFor('E1'), 'دعائے کمیل');
      // An empty title is no title.
      expect(translations.titleFor('G17|L4'), isNull);
      expect(translations.displayTitle('E2', 'Dua Nudba'), 'Dua Nudba');

      final document = await translations.documentFor('E1', bundle);
      expect(document, isNotNull);
      expect(document!.merits, 'فضیلت');
      expect(document.segment(0), 'اے اللہ');
      expect(document.segment(1), isNull);
      // Empty values and keys that are not numbers are dropped.
      expect(document.segments.keys, [0]);
    });

    test('a zikr with no file of its own has no translation', () async {
      await translations.setLanguage('ur', bundle);
      expect(await translations.documentFor('E9', bundle), isNull);
    });

    test('names recordings and reciters, never in English', () async {
      expect(translations.audioLabelFor('quran/surah-001.mp3', 'Al-Fatihah'),
          'Al-Fatihah');
      expect(translations.reciterName('Ali Fani'), 'Ali Fani');

      await translations.setLanguage('ur', bundle);
      expect(translations.audioLabelFor('quran/surah-001.mp3', 'Al-Fatihah'),
          'سورہ فاتحہ');
      expect(translations.audioLabelFor('quran/surah-002.mp3', 'Al-Baqarah'),
          isNull);
      expect(translations.audioLabelFor('quran/surah-001.mp3', null), isNull);
      expect(translations.reciterName('Ali Fani'), 'علی فانی');
      expect(translations.reciterName('Mahdi Sahwan'), isNull);
    });

    test('transliteration is shown only in English', () async {
      showTransliteration = true;
      expect(transliterationShown, isTrue);
      await translations.setLanguage('ur', bundle);
      expect(transliterationShown, isFalse);
    });

    test('a language with nothing shipped leaves everything in English',
        () async {
      await translations.setLanguage('fa', bundle);
      expect(translations.isEnglish, isTrue);
      expect(translations.titleFor('E1'), isNull);
      expect(await translations.documentFor('E1', bundle), isNull);

      await translations.setLanguage('xx', bundle);
      expect(translations.isEnglish, isTrue);
    });
  });

  group('shipped zikr translations', () {
    final root = Directory('assets/zikr_i18n');
    final languageDirs = root.existsSync()
        ? root.listSync().whereType<Directory>().toList()
        : <Directory>[];
    final declared = ((loadYaml(File('pubspec.yaml').readAsStringSync())
            as Map)['flutter']['assets'] as YamlList)
        .map((entry) => entry.toString())
        .toSet();

    test('every language folder is a known language with an index', () {
      for (final dir in languageDirs) {
        final code = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
        expect(appLanguageFor(code), isNotNull,
            reason: '$code is not in lib/l10n/app_language.dart');
        expect(File('${dir.path}/index.json').existsSync(), isTrue,
            reason: 'assets/zikr_i18n/$code/index.json is what makes the app '
                'offer $code');
      }
    });

    test('every language folder is bundled', () {
      for (final dir in languageDirs) {
        final code = dir.uri.pathSegments.where((s) => s.isNotEmpty).last;
        expect(declared, contains('assets/zikr_i18n/$code/'),
            reason: 'Add "- assets/zikr_i18n/$code/" to pubspec.yaml, or the '
                'translations are left out of the app.');
      }
    });

    test('every file is well-formed and names a real zikr', () {
      for (final dir in languageDirs) {
        for (final file in dir.listSync().whereType<File>()) {
          final name = file.uri.pathSegments.last;
          if (!name.endsWith('.json')) {
            fail('${file.path}: only .json files belong here');
          }
          final decoded = jsonDecode(file.readAsStringSync());
          expect(decoded, isA<Map>(), reason: file.path);
          // A template's "_" reference (each segment's Arabic and English)
          // would bundle the zikr into the app a second time.
          void expectNoReference(Object? value) {
            if (value is! Map) return;
            for (final entry in value.entries) {
              expect((entry.key as String).startsWith('_'), isFalse,
                  reason: '${file.path}: "${entry.key}" is template '
                      'reference; run python3 scripts/zikr_i18n/zikr_i18n.py '
                      'rebase to strip it');
              expectNoReference(entry.value);
            }
          }

          expectNoReference(decoded);
          expect((decoded as Map).containsKey('lines'), isFalse,
              reason: '${file.path}: "lines" is the old English-keyed format; '
                  'run python3 scripts/zikr_i18n/zikr_i18n.py migrate');
          if (name == 'index.json') {
            final titles = decoded['titles'];
            if (titles != null) expect(titles, isA<Map>(), reason: file.path);
            final audio = decoded['audio'];
            if (audio != null) expect(audio, isA<Map>(), reason: file.path);
            continue;
          }
          final uid = name.substring(0, name.length - '.json'.length);
          expect(File('assets/zikr/$uid').existsSync(), isTrue,
              reason: '${file.path} translates a zikr that does not exist');
          final merits = decoded['merits'];
          if (merits != null) expect(merits, isA<String>(), reason: file.path);
          final segments = decoded['segments'];
          if (segments != null) {
            expect(segments, isA<Map>(), reason: '${file.path}: "segments"');
            for (final entry in (segments as Map).entries) {
              expect(int.tryParse(entry.key as String), isNotNull,
                  reason: '${file.path}: segment keys are numbers');
              expect(entry.value, isA<String>(),
                  reason: '${file.path}: ${entry.key}');
            }
          }
        }
      }
    });

    // Translations are keyed by segment number, so an edit to a translated
    // zikr's content - a restored verse, a split line - would shift them
    // onto the wrong lines. Each translated zikr's segments are pinned; when
    // this fails, run `python3 scripts/zikr_i18n/zikr_i18n.py rebase`, which
    // renumbers the translations to follow the edit and re-pins the zikr.
    test('translated zikrs still have the segments they were translated for',
        () {
      final anchorsFile = File('scripts/zikr_i18n/segment_anchors.json');
      final pinned = anchorsFile.existsSync()
          ? jsonDecode(anchorsFile.readAsStringSync()) as Map
          : const {};
      for (final dir in languageDirs) {
        for (final file in dir.listSync().whereType<File>()) {
          final name = file.uri.pathSegments.last;
          if (name == 'index.json' || !name.endsWith('.json')) continue;
          final uid = name.substring(0, name.length - '.json'.length);
          final content = File('assets/zikr/$uid');
          if (!content.existsSync()) continue;
          final segments = _segmentsOf(Map<String, dynamic>.from(
              jsonDecode(content.readAsStringSync()) as Map));
          expect(pinned[uid], segments.map((s) => s.$1).toList(),
              reason: 'assets/zikr/$uid changed since it was translated (or '
                  'was never pinned): run python3 '
                  'scripts/zikr_i18n/zikr_i18n.py rebase');

          final translated = (jsonDecode(file.readAsStringSync())
                  as Map)['segments'] as Map? ??
              const {};
          for (final key in translated.keys) {
            final number = int.parse(key as String);
            expect(number < segments.length && segments[number].$2, isTrue,
                reason: '${file.path}: segment $number has nothing to '
                    'translate');
          }
        }
      }
    });
  });
}
