import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/l10n/app_language.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';
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
const _content = 'Say the following:\n'
    'اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ\n'
    'ALLAAHUMMA SALLE A’LAA MOHAMMADIN\n'
    'O Allah, bless Muhammad\n'
    'اَللّٰهُمَّ اغْفِرْ لِيْ\n'
    'ALLAAHUMMAGH FIR LEE\n'
    'O Allah, forgive me';

void main() {
  group('ParsedZikrContent.translatedWith', () {
    final parsed =
        ZikrContentParser.parseContent(_content, hideHeaderLine: false);

    test('replaces translation and standalone lines only', () {
      final translated = parsed.translatedWith(const ZikrDocumentTranslation(
        language: _urdu,
        lines: {
          'Say the following:': 'یہ پڑھیں:',
          'O Allah, bless Muhammad': 'اے اللہ، محمد پر رحمت نازل فرما',
          // Arabic and transliteration are never looked up.
          'ALLAAHUMMA SALLE A’LAA MOHAMMADIN': 'should not appear',
        },
      ));

      expect(translated.displayLine(0), 'یہ پڑھیں:');
      expect(translated.displayLine(3), 'اے اللہ، محمد پر رحمت نازل فرما');
      expect(translated.displayLine(2), 'ALLAAHUMMA SALLE A’LAA MOHAMMADIN');
      // An untranslated line stays English.
      expect(translated.displayLine(6), 'O Allah, forgive me');
    });

    test('keeps the English lines and the parse they produced', () {
      final translated = parsed.translatedWith(const ZikrDocumentTranslation(
        language: _urdu,
        lines: {'O Allah, bless Muhammad': 'اے اللہ، محمد پر رحمت نازل فرما'},
      ));

      // Urdu is in Arabic script; were it re-parsed it would count as a
      // verse. Bookmarks and verse matching key off these.
      expect(translated.lines, parsed.lines);
      expect(translated.arabicCodes, parsed.arabicCodes);
      expect(translated.transliCodes, parsed.transliCodes);
      expect(translated.translaCodes, parsed.translaCodes);
    });

    test('reads each line in its own direction', () {
      final translated = parsed.translatedWith(const ZikrDocumentTranslation(
        language: _urdu,
        lines: {'O Allah, bless Muhammad': 'اے اللہ، محمد پر رحمت نازل فرما'},
      ));

      expect(translated.directionOf(1), TextDirection.rtl); // Arabic
      expect(translated.directionOf(2), TextDirection.ltr); // transliteration
      expect(translated.directionOf(3), TextDirection.rtl); // Urdu
      expect(translated.directionOf(6), TextDirection.ltr); // still English
    });

    test('is a no-op without a translation', () {
      expect(identical(parsed.translatedWith(null), parsed), isTrue);
    });
  });

  group('the reader', () {
    setUp(() {
      showTranslation = true;
      showTransliteration = true;
      showArabicAsParagraph = false;
    });

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

    testWidgets('draws translated lines right-to-left in place of the English',
        (tester) async {
      await pumpViewer(
        tester,
        const ZikrDocumentTranslation(
          language: _urdu,
          lines: {
            'O Allah, bless Muhammad': 'اے اللہ، محمد پر رحمت نازل فرما',
            'Say the following:': 'یہ پڑھیں:',
          },
        ),
      );

      final urdu =
          find.text('اے اللہ، محمد پر رحمت نازل فرما', findRichText: true);
      expect(urdu, findsOneWidget);
      expect(tester.widget<RichText>(urdu).textDirection, TextDirection.rtl);
      expect(find.text('O Allah, bless Muhammad', findRichText: true),
          findsNothing);

      // The instruction box takes the translation's direction too.
      final instruction = find.text('یہ پڑھیں:', findRichText: true);
      expect(instruction, findsOneWidget);
      expect(
        Directionality.of(tester.element(instruction)),
        TextDirection.rtl,
      );

      // The untranslated line stays English, left to right; the Arabic and
      // transliteration are untouched.
      final english = find.text('O Allah, forgive me', findRichText: true);
      expect(english, findsOneWidget);
      expect(tester.widget<RichText>(english).textDirection, TextDirection.ltr);
      expect(find.text('ALLAAHUMMA SALLE A’LAA MOHAMMADIN', findRichText: true),
          findsOneWidget);
    });

    testWidgets('shows the English without a translation', (tester) async {
      await pumpViewer(tester, null);
      expect(find.text('O Allah, bless Muhammad', findRichText: true),
          findsOneWidget);
      expect(
          find.text('Say the following:', findRichText: true), findsOneWidget);
    });
  });

  group('ZikrDocumentTranslation.lineFor', () {
    const translation = ZikrDocumentTranslation(
      language: _urdu,
      lines: {'In the Name of Allah': 'اللہ کے نام سے (اس دعا میں)'},
      sharedLines: {
        'In the Name of Allah': 'اللہ کے نام سے',
        'Peace be upon you': 'آپ پر سلام ہو',
        'Blank': '   ',
      },
    );

    test('prefers the zikr’s own line over the shared one', () {
      expect(translation.lineFor('In the Name of Allah'),
          'اللہ کے نام سے (اس دعا میں)');
    });

    test('falls back to the shared lines, then to null', () {
      expect(translation.lineFor('  Peace be upon you '), 'آپ پر سلام ہو');
      expect(translation.lineFor('Something else'), isNull);
      expect(translation.lineFor('Blank'), isNull);
      expect(translation.lineFor(''), isNull);
    });
  });

  group('ZikrTranslations', () {
    final translations = ZikrTranslations.instance;

    final bundle = _FakeBundle({
      'assets/zikr_i18n/ur/index.json': jsonEncode({
        'titles': {'E1': 'دعائے کمیل', 'G17|L4': ''},
        'lines': {'Peace be upon you': 'آپ پر سلام ہو'},
      }),
      'assets/zikr_i18n/ur/E1.json': jsonEncode({
        'merits': 'فضیلت',
        'lines': {'O Allah': 'اے اللہ', 'Untranslated': ''},
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
      expect(document.lineFor('O Allah'), 'اے اللہ');
      expect(document.lineFor('Untranslated'), isNull);
      expect(document.lineFor('Peace be upon you'), 'آپ پر سلام ہو');
    });

    test('a zikr with no file of its own still gets the shared lines',
        () async {
      await translations.setLanguage('ur', bundle);
      final document = await translations.documentFor('E9', bundle);
      expect(document?.lineFor('Peace be upon you'), 'آپ پر سلام ہو');
      expect(document?.merits, isNull);
    });

    test('a language with nothing shipped leaves everything in English',
        () async {
      await translations.setLanguage('fa', bundle);
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
          final lines = (decoded as Map)['lines'];
          if (lines != null) {
            expect(lines, isA<Map>(), reason: '${file.path}: "lines"');
            for (final entry in (lines as Map).entries) {
              expect(entry.value, isA<String>(),
                  reason: '${file.path}: ${entry.key}');
            }
          }
          if (name == 'index.json') {
            final titles = decoded['titles'];
            if (titles != null) expect(titles, isA<Map>(), reason: file.path);
            continue;
          }
          final uid = name.substring(0, name.length - '.json'.length);
          expect(File('assets/zikr/$uid').existsSync(), isTrue,
              reason: '${file.path} translates a zikr that does not exist');
          final merits = decoded['merits'];
          if (merits != null) expect(merits, isA<String>(), reason: file.path);
        }
      }
    });
  });
}
