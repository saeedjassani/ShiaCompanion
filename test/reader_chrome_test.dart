import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/l10n/app_language.dart';
import 'package:shia_companion/l10n/app_localizations.dart';
import 'package:shia_companion/services/content_request_service.dart';
import 'package:shia_companion/services/zikr_translations.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/reader_text_sheet.dart';
import 'package:shia_companion/widgets/reader_top_bar.dart';

Widget _host(Widget child) => MaterialApp(
      theme: buildAppTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

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
    final text = files[key];
    if (text == null) throw FlutterError('Missing asset: $key');
    return ByteData.sublistView(Uint8List.fromList(text.codeUnits));
  }
}

final _translationBundle = _FakeBundle({
  zikrTranslationIndexPath('ar'): '{"titles": {}}',
  zikrTranslationIndexPath('ur'): '{"titles": {}}',
});

void main() {
  test('a translation request names the language and the zikr', () {
    const urdu =
        AppLanguage(code: 'ur', englishName: 'Urdu', nativeName: 'اردو');
    expect(translationRequestTitle('Dua Kumayl', urdu),
        'Urdu translation: Dua Kumayl');
    expect(translationRequestTitle('x' * 300, urdu).length, 200);
  });

  group('ReaderTopBar', () {
    testWidgets('shows the title without its trailing Arabic, and the sub-line',
        (t) async {
      await t.pumpWidget(_host(const ReaderTopBar(
        title: '2: Al-Baqarah البقرة',
        subtitle: Text('12% read'),
      )));

      expect(find.text('2: Al-Baqarah'), findsOneWidget);
      expect(find.text('12% read'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a title that is all Arabic is kept whole', (t) async {
      await t.pumpWidget(_host(const ReaderTopBar(title: 'البقرة')));

      expect(find.text('البقرة'), findsOneWidget);
    });

    testWidgets('draws the progress line only when given progress', (t) async {
      await t.pumpWidget(_host(const ReaderTopBar(title: 'Dua Kumayl')));
      expect(find.byType(ReaderProgressLine), findsNothing);

      final progress = ValueNotifier<double>(0.12);
      addTearDown(progress.dispose);
      await t.pumpWidget(
          _host(ReaderTopBar(title: 'Dua Kumayl', progress: progress)));
      expect(find.byType(ReaderProgressLine), findsOneWidget);
      expect(
          t.getSize(find.byType(ReaderTopBar)).height, ReaderTopBar.barHeight);
    });
  });

  group('ReaderTextSheet', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({'showTransliteration': true});
      await SP.init();
      arabicFontSize = 32;
      englishFontSize = 16;
      showTransliteration = true;
      showTranslation = true;
      showArabicAsParagraph = false;
    });

    Future<int> pumpSheet(WidgetTester t) async {
      var changes = 0;
      await t.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_host(ReaderTextSheet(onChanged: () => changes++)));
      return changes;
    }

    testWidgets('offers Auto-scroll only from the reader', (t) async {
      await pumpSheet(t);
      expect(find.text('Auto-scroll'), findsNothing);

      var started = 0;
      await t.pumpWidget(_host(ReaderTextSheet(
        onChanged: () {},
        onStartAutoScroll: () => started++,
      )));
      expect(find.text('Auto-scroll'), findsOneWidget);

      await t.tap(find.text('Start'));
      await t.pump();
      expect(started, 1);
    });

    testWidgets('A+ and A− step the Arabic size by 2 and save it', (t) async {
      var changes = 0;
      await t.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(_host(ReaderTextSheet(onChanged: () => changes++)));

      await t.tap(find.bySemanticsLabel('Bigger Arabic'));
      await t.pump();
      expect(arabicFontSize, 34);
      expect(SP.prefs.getDouble('ara_font_size'), 34);
      expect(find.text('34'), findsOneWidget);

      await t.tap(find.bySemanticsLabel('Smaller English'));
      await t.pump();
      expect(englishFontSize, 15);
      expect(changes, 2);
    });

    testWidgets('Arabic as one paragraph waits for both English aids to be off',
        (t) async {
      await pumpSheet(t);

      Switch paragraphSwitch() => t.widget<Switch>(find.descendant(
            of: find.ancestor(
              of: find.text('Arabic as one paragraph'),
              matching: find.byType(InkWell),
            ),
            matching: find.byType(Switch),
          ));
      expect(paragraphSwitch().onChanged, isNull);

      await t.tap(find.text('Transliteration'));
      await t.pumpAndSettle();
      await t.tap(find.text('Translation'));
      await t.pumpAndSettle();

      expect(showTransliteration, isFalse);
      expect(SP.prefs.getBool('showTranslation'), isFalse);
      expect(paragraphSwitch().onChanged, isNotNull);
    });

    group('in another reading language', () {
      final translations = ZikrTranslations.instance;
      setUp(translations.debugReset);
      tearDown(translations.debugReset);

      const zikr = UntranslatedZikr(uid: 'E31', englishTitle: 'Dua Kumayl');

      testWidgets('Arabic has no Translation switch, and paragraphs are free',
          (t) async {
        await t
            .runAsync(() => translations.setLanguage('ar', _translationBundle));
        await t.binding.setSurfaceSize(const Size(390, 1200));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(_host(const ReaderTextSheet(
          onChanged: _noop,
          untranslated: zikr,
        )));

        expect(find.text('Translation'), findsNothing);
        expect(find.text('Transliteration'), findsNothing);
        expect(find.text('Request'), findsNothing);
        expect(showTranslation, isTrue, reason: 'the setting is left alone');
        expect(translationShown, isFalse);
        final paragraph = t.widget<Switch>(find.descendant(
          of: find.ancestor(
            of: find.text('Arabic as one paragraph'),
            matching: find.byType(InkWell),
          ),
          matching: find.byType(Switch),
        ));
        expect(paragraph.onChanged, isNotNull);
      });

      testWidgets('an untranslated zikr offers a request, not a switch',
          (t) async {
        await t
            .runAsync(() => translations.setLanguage('ur', _translationBundle));
        await t.binding.setSurfaceSize(const Size(390, 1200));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(_host(const ReaderTextSheet(
          onChanged: _noop,
          untranslated: zikr,
        )));

        expect(find.text('Translation'), findsOneWidget);
        expect(find.text('Not yet available in اردو'), findsOneWidget);
        expect(find.text('Request'), findsOneWidget);
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text('Translation'),
              matching: find.byType(Row),
            ),
            matching: find.byType(Switch),
          ),
          findsNothing,
        );
        expect(SP.prefs.getBool('showTranslation'), isNull,
            reason: 'other zikrs keep the reader\'s own setting');
      });

      testWidgets('a zikr already asked for reads Requested', (t) async {
        await SP.prefs.setBool('translation_requested_ur_E31', true);
        await t
            .runAsync(() => translations.setLanguage('ur', _translationBundle));
        await t.binding.setSurfaceSize(const Size(390, 1200));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(_host(const ReaderTextSheet(
          onChanged: _noop,
          untranslated: zikr,
        )));

        expect(find.text('Requested'), findsOneWidget);
        expect(find.text('Request'), findsNothing);
      });

      testWidgets('a translated zikr keeps its switch', (t) async {
        await t
            .runAsync(() => translations.setLanguage('ur', _translationBundle));
        await t.binding.setSurfaceSize(const Size(390, 1200));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(_host(const ReaderTextSheet(onChanged: _noop)));

        expect(find.text('Translation'), findsOneWidget);
        expect(find.text('Request'), findsNothing);
      });

      testWidgets('English ignores the untranslated zikr', (t) async {
        await t.binding.setSurfaceSize(const Size(390, 1200));
        addTearDown(() => t.binding.setSurfaceSize(null));
        await t.pumpWidget(_host(const ReaderTextSheet(
          onChanged: _noop,
          untranslated: zikr,
        )));

        expect(find.text('Translation'), findsOneWidget);
        expect(find.text('Request'), findsNothing);
      });
    });
  });
}

void _noop() {}
