import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';
import 'package:shia_companion/l10n/app_language.dart';
import 'package:shia_companion/services/zikr_translations.dart';

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

const _verse1 = 'اَللّٰهُمَّ صَلِّ عَلٰى مُحَمَّدٍ';
const _verse2 = 'اَللّٰهُمَّ اغْفِرْ لِيْ';
const _verse3 = 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ';
const _translation1 = 'O Allah, bless Muhammad';
const _translation2 = 'O Allah, forgive me';
const _translation3 = 'Praise be to Allah';

// An instruction, then Arabic / transliteration / translation triplets.
// Segments: 0 the instruction, 1 and 2 the verses.
const _triplets = 'Say the following:\n'
    '$_verse1\n'
    'ALLAAHUMMA SALLE A’LAA MOHAMMADIN\n'
    '$_translation1\n'
    '$_verse2\n'
    'ALLAAHUMMAGH FIR LEE\n'
    '$_translation2';

// Verses with no transliteration (the instruction leads, because an English
// line straight after an Arabic verse is read as that verse's translation).
const _plain = 'Recite:\n'
    '$_verse1\n'
    '$_translation1\n'
    '$_verse2\n'
    '$_translation2\n'
    '$_verse3\n'
    '$_translation3';

Future<void> _pump(
  WidgetTester tester, {
  String content = _triplets,
  ZikrDocumentTranslation? translation,
  int? surahNumber,
  ValueChanged<AyahActionRequest>? onAyahAction,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZikrContentViewerWidget(
          tabContents: <String>[content],
          selectedTabIndex: 0,
          onTabChanged: (_) {},
          hasMerits: false,
          onShowMerits: () {},
          onLinkTap: (_) async {},
          translation: translation,
          surahNumber: surahNumber,
          onAyahAction: onAyahAction,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _text(String text) => find.text(text, findRichText: true);
Finder _arabic(String text) => find.textContaining(text, findRichText: true);

void main() {
  final translations = ZikrTranslations.instance;

  setUp(() {
    translations.debugReset();
    showTranslation = false;
    showTransliteration = false;
    showArabicAsParagraph = false;
  });

  tearDown(() {
    translations.debugReset();
    showTranslation = true;
    showTransliteration = false;
    showArabicAsParagraph = false;
  });

  group('a zikr read with translation off', () {
    testWidgets('opens one verse\'s translation on a tap, and hides it on '
        'the next', (tester) async {
      await _pump(tester);
      expect(_text(_translation1), findsNothing);
      expect(_text(_translation2), findsNothing);

      await tester.tap(_arabic('صَلِّ'));
      await tester.pumpAndSettle();
      expect(_text(_translation1), findsOneWidget);
      expect(_text(_translation2), findsNothing,
          reason: 'only the tapped verse opens');

      await tester.tap(_arabic('صَلِّ'));
      await tester.pumpAndSettle();
      expect(_text(_translation1), findsNothing);
    });

    testWidgets('a tap on the opened translation hides it again',
        (tester) async {
      await _pump(tester);
      await tester.tap(_arabic('اغْفِرْ'));
      await tester.pumpAndSettle();
      expect(_text(_translation2), findsOneWidget);

      await tester.tap(_text(_translation2));
      await tester.pumpAndSettle();
      expect(_text(_translation2), findsNothing);
    });

    testWidgets('draws the opened translation as the translation line is',
        (tester) async {
      await _pump(tester);
      await tester.tap(_arabic('صَلِّ'));
      await tester.pumpAndSettle();

      final peeked = tester.widget<RichText>(_text(_translation1));

      showTranslation = true;
      await _pump(tester);
      final shown = tester.widget<RichText>(_text(_translation1));

      expect(peeked.text.style?.fontSize, shown.text.style?.fontSize);
      expect(peeked.text.style?.color, shown.text.style?.color);
      expect(peeked.textAlign, shown.textAlign);
    });

    testWidgets('turning translation on and off again closes what was opened',
        (tester) async {
      await _pump(tester);
      await tester.tap(_arabic('صَلِّ'));
      await tester.pumpAndSettle();
      expect(_text(_translation1), findsOneWidget);

      showTranslation = true;
      await _pump(tester);
      expect(_text(_translation1), findsOneWidget);
      expect(_text(_translation2), findsOneWidget);

      showTranslation = false;
      await _pump(tester);
      expect(_text(_translation1), findsNothing);
    });

    testWidgets('shows the transliteration only if that is on too',
        (tester) async {
      showTransliteration = true;
      await _pump(tester);
      await tester.tap(_arabic('صَلِّ'));
      await tester.pumpAndSettle();

      expect(_text(_translation1), findsOneWidget);
      expect(_text('ALLAAHUMMA SALLE A’LAA MOHAMMADIN'), findsOneWidget);
      expect(_text('ALLAAHUMMAGH FIR LEE'), findsOneWidget);
      expect(_text(_translation2), findsNothing);
    });

    testWidgets('lifts a verse out of the Arabic paragraph while it is open',
        (tester) async {
      showArabicAsParagraph = true;
      await _pump(tester, content: _plain);

      final paragraph = find.byWidgetPredicate((widget) =>
          widget is RichText &&
          widget.text.toPlainText().contains(_verse1) &&
          widget.text.toPlainText().contains(_verse3));
      expect(paragraph, findsOneWidget, reason: 'flowing as one paragraph');

      // Arabic starts at the right edge, so the first verse is there.
      await tester.tapAt(tester.getTopRight(paragraph) + const Offset(-4, 10));
      await tester.pumpAndSettle();

      expect(_text(_translation1), findsOneWidget);
      expect(_text(_translation2), findsNothing);
      expect(_arabic(_verse1), findsOneWidget);
      expect(_arabic(_verse3), findsOneWidget);

      await tester.tap(_text(_translation1));
      await tester.pumpAndSettle();
      expect(_text(_translation1), findsNothing);
      expect(paragraph, findsOneWidget, reason: 'flowing again');
    });

    testWidgets('with translation on, a tap changes nothing', (tester) async {
      showTranslation = true;
      await _pump(tester);

      await tester.tap(_arabic('صَلِّ'));
      await tester.pumpAndSettle();

      expect(_text(_translation1), findsOneWidget);
      expect(_text(_translation2), findsOneWidget);
    });
  });

  group('in another language', () {
    final bundle = _FakeBundle({
      'assets/zikr_i18n/ur/index.json': jsonEncode({'titles': {}}),
      'assets/zikr_i18n/ar/index.json': jsonEncode({'titles': {}}),
    });

    testWidgets('opens a verse that has a translation, and only that',
        (tester) async {
      await tester.runAsync(() => translations.setLanguage('ur', bundle));
      const urdu = 'اے اللہ، مجھے بخش دے';
      await _pump(
        tester,
        translation: const ZikrDocumentTranslation(
          language: _urdu,
          segments: {2: urdu},
        ),
      );

      // The untranslated verse has nothing to show: English never fills in.
      await tester.tap(_arabic('صَلِّ'));
      await tester.pumpAndSettle();
      expect(_text(_translation1), findsNothing);

      await tester.tap(_arabic('اغْفِرْ'));
      await tester.pumpAndSettle();
      expect(_text(urdu), findsOneWidget);
      expect(_text(_translation2), findsNothing);
    });

    testWidgets('does nothing in Arabic, which has no translation',
        (tester) async {
      await tester.runAsync(() => translations.setLanguage('ar', bundle));
      await _pump(tester);

      await tester.tap(_arabic('صَلِّ'));
      await tester.pumpAndSettle();

      expect(_text(_translation1), findsNothing);
      expect(_text(_translation2), findsNothing);
    });
  });

  group('the Quran reader, where a tap is already the verse menu', () {
    // Triplets, as every surah is, behind a Bismillah.
    final surah = [
      'بِسْمِ اللهِ الرَّحْمٰنِ الرَّحِيْمِ',
      for (var ayah = 1; ayah <= 3; ayah++) ...[
        'اَلْحَمْدُ لِلّٰهِ رَبِّ الْعٰلَمِيْنَ ($ayah)',
        'TRANSLITERATION $ayah',
        'Translation of ayah $ayah',
      ],
    ].join('\n');

    testWidgets('hands the verse menu its translation to show', (tester) async {
      AyahActionRequest? request;
      await _pump(
        tester,
        content: surah,
        surahNumber: 1,
        onAyahAction: (value) => request = value,
      );

      await tester.tap(_arabic('اَلْحَمْدُ').at(1));
      await tester.pumpAndSettle();
      expect(request!.verse.ayah, 2);
      expect(request!.translation, 'Translation of ayah 2');
      expect(request!.translationDirection, TextDirection.ltr);
      // Nothing opens under the verse: the menu shows it.
      expect(_text('Translation of ayah 2'), findsNothing);
    });

    testWidgets('hands it none while translation is on', (tester) async {
      showTranslation = true;
      AyahActionRequest? request;
      await _pump(
        tester,
        content: surah,
        surahNumber: 1,
        onAyahAction: (value) => request = value,
      );

      await tester.tap(_text('Translation of ayah 2'));
      await tester.pumpAndSettle();

      expect(request!.translation, isNull);
    });

    testWidgets('hands it the tapped verse in paragraph mode', (tester) async {
      showArabicAsParagraph = true;
      AyahActionRequest? request;
      await _pump(
        tester,
        content: surah,
        surahNumber: 1,
        onAyahAction: (value) => request = value,
      );

      final paragraph = find.byWidgetPredicate((widget) =>
          widget is RichText && widget.text.toPlainText().contains('(1)'));
      await tester.tapAt(tester.getTopRight(paragraph) + const Offset(-4, 10));
      await tester.pumpAndSettle();
      expect(request, isNotNull);
      expect(request!.verse.ayah, 1);
      expect(request!.translation, 'Translation of ayah 1');
      expect(_text('Translation of ayah 1'), findsNothing);
    });
  });
}
