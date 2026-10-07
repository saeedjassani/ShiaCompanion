import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/l10n/app_localizations.dart';
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

void main() {
  group('ReaderTopBar', () {
    testWidgets('shows the title without its trailing Arabic, and the sub-line',
        (t) async {
      await t.pumpWidget(_host(const ReaderTopBar(
        title: '2: Al-Baqarah البقرة',
        subtitle: Text('Verse 255 of 286 · My reading'),
      )));

      expect(find.text('2: Al-Baqarah'), findsOneWidget);
      expect(find.text('Verse 255 of 286 · My reading'), findsOneWidget);
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
      expect(t.getSize(find.byType(ReaderTopBar)).height,
          ReaderTopBar.barHeight);
    });
  });

  group('ReaderTextSheet', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
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

    testWidgets('offers a reminder row only when the page can set one',
        (t) async {
      await pumpSheet(t);
      expect(find.text('Remind me to read this'), findsNothing);

      var reminders = 0;
      await t.pumpWidget(_host(ReaderTextSheet(
        onChanged: () {},
        onSetReminder: () => reminders++,
      )));
      expect(find.text('Remind me to read this'), findsOneWidget);
    });
  });
}
