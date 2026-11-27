import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/l10n/app_localizations.dart';
import 'package:shia_companion/models/quran_listening.dart';
import 'package:shia_companion/models/zikr_audio_track.dart';
import 'package:shia_companion/services/preferences_sync_service.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/quran_reciter_sheet.dart';

void main() {
  const recording = ZikrAudioTrack(
    url: 'https://example.com/quran/shakernejad/surah-036.mp3',
    label: 'Surah Ya-Sin',
    reciter: 'Hamed Shakernejad',
  );

  group('the Quran reciter preference', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SP.init();
    });

    test('is verse by verse until the reader chooses', () {
      expect(
        PreferencesSyncService.instance.quranReciter,
        QuranListenReciter.verses,
      );
    });

    test('remembers the recording once chosen, and back again', () async {
      final prefs = PreferencesSyncService.instance;
      await prefs.setQuranReciter(QuranListenReciter.recording);
      expect(prefs.quranReciter, QuranListenReciter.recording);
      expect(SP.prefs.getString(QuranListenReciter.prefKey), 'recording');

      await prefs.setQuranReciter(QuranListenReciter.verses);
      expect(prefs.quranReciter, QuranListenReciter.verses);
    });
  });

  testWidgets('the reciter sheet names both reciters and returns the choice',
      (tester) async {
    QuranListenReciter? picked;
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              picked = await showQuranReciterSheet(
                context,
                recording: recording,
                current: QuranListenReciter.verses,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Choose reciter'), findsOneWidget);
    expect(find.text(quranVerseReciter), findsOneWidget);
    expect(find.text('Hamed Shakernejad'), findsOneWidget);
    expect(find.text('Verse by verse, following the text'), findsOneWidget);
    expect(find.text('The whole surah in one recording'), findsOneWidget);

    await tester.tap(find.text('Hamed Shakernejad'));
    await tester.pumpAndSettle();
    expect(picked, QuranListenReciter.recording);
  });
}
