import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/l10n/l10n.dart';
import 'package:shia_companion/services/audio_playback_speed.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
    AudioPlaybackSpeed.current.value = AudioPlaybackSpeed.normal;
  });

  test('plays at normal speed until another is chosen', () {
    expect(AudioPlaybackSpeed.current.value, 1.0);
    expect(AudioPlaybackSpeed.choices, contains(AudioPlaybackSpeed.normal));
  });

  test('keeps the chosen speed for the next recitation', () async {
    await AudioPlaybackSpeed.set(1.5);
    expect(AudioPlaybackSpeed.current.value, 1.5);
    expect(SP.prefs.getDouble(AudioPlaybackSpeed.prefKey), 1.5);
  });

  test('ignores a speed the picker does not offer', () async {
    await AudioPlaybackSpeed.set(3.0);
    expect(AudioPlaybackSpeed.current.value, 1.0);
    expect(SP.prefs.getDouble(AudioPlaybackSpeed.prefKey), isNull);
  });

  test('labels a speed in the app language', () {
    L10n.current = lookupAppLocalizations(const Locale('en'));
    expect(AudioPlaybackSpeed.label(1.25), '1.25×');
    expect(AudioPlaybackSpeed.label(1.0), '1×');
    L10n.current = lookupAppLocalizations(const Locale('fr'));
    expect(AudioPlaybackSpeed.label(0.75), '0,75×');
    L10n.current = lookupAppLocalizations(const Locale('en'));
  });

  testWidgets('the picker offers every speed and applies the one chosen', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => AudioPlaybackSpeed.pick(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Playback speed'), findsOneWidget);
    for (final label in [
      '0.5×',
      '0.75×',
      '1×',
      '1.25×',
      '1.5×',
      '1.75×',
      '2×',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Normal'), findsOneWidget);

    await tester.tap(find.text('1.5×'));
    await tester.pumpAndSettle();
    expect(find.text('Playback speed'), findsNothing);
    expect(AudioPlaybackSpeed.current.value, 1.5);
    expect(SP.prefs.getDouble(AudioPlaybackSpeed.prefKey), 1.5);
  });
}
