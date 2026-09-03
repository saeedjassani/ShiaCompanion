import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/pages/zikr/zikr_content_viewer.dart';
import 'package:shia_companion/utils/font_preferences.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/utils/zikr_wakelock.dart';
import 'package:shia_companion/widgets/zikr_reading_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart' as wakelock;
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _FakeWakelockPlatform extends WakelockPlusPlatformInterface {
  bool isEnabled = false;
  final List<bool> toggles = <bool>[];

  @override
  Future<void> toggle({required bool enable}) async {
    toggles.add(enable);
    isEnabled = enable;
  }

  @override
  Future<bool> get enabled async => isEnabled;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late WakelockPlusPlatformInterface originalWakelockPlatform;
  late _FakeWakelockPlatform fakeWakelock;
  late Object wakelockOwner;

  setUp(() async {
    originalWakelockPlatform = wakelock.wakelockPlusPlatformInstance;
    fakeWakelock = _FakeWakelockPlatform();
    wakelock.wakelockPlusPlatformInstance = fakeWakelock;
    wakelockOwner = Object();
    _resetReadingGlobals();
  });

  tearDown(() {
    syncZikrWakelockPreference(owner: wakelockOwner, isActive: false);
    wakelock.wakelockPlusPlatformInstance = originalWakelockPlatform;
    _resetReadingGlobals();
  });

  testWidgets('keep screen on preference controls active zikr wakelock',
      (tester) async {
    await _initPrefs(<String, Object>{});

    syncZikrWakelockPreference(owner: wakelockOwner, isActive: true);

    expect(fakeWakelock.isEnabled, isTrue);
    expect(fakeWakelock.toggles, <bool>[true]);

    fakeWakelock.toggles.clear();
    await _pumpPreferences(
      tester,
      onChanged: () =>
          syncZikrWakelockPreference(owner: wakelockOwner, isActive: true),
    );

    await _tapPreference(tester, 'Keep screen on while reciting Zikr');
    expect(SP.prefs.getBool('keep_awake'), isFalse);
    expect(fakeWakelock.isEnabled, isFalse);
    expect(fakeWakelock.toggles.last, isFalse);

    await _tapPreference(tester, 'Keep screen on while reciting Zikr');
    expect(SP.prefs.getBool('keep_awake'), isTrue);
    expect(fakeWakelock.isEnabled, isTrue);
    expect(fakeWakelock.toggles.last, isTrue);
  });

  testWidgets('boolean reading preferences persist and update runtime flags',
      (tester) async {
    await _initPrefs(<String, Object>{
      'share_zikr_image': false,
      'showTransliteration': false,
      'showTranslation': false,
    });
    showTransliteration = false;
    showTranslation = false;

    await _pumpPreferences(tester);

    await _tapPreference(tester, 'Share Zikr as Image');
    expect(SP.prefs.getBool('share_zikr_image'), isTrue);

    await _tapPreference(tester, 'Show Transliteration');
    expect(SP.prefs.getBool('showTransliteration'), isTrue);
    expect(showTransliteration, isTrue);

    await _tapPreference(tester, 'Show Translation');
    expect(SP.prefs.getBool('showTranslation'), isTrue);
    expect(showTranslation, isTrue);
  });

  testWidgets('font preferences persist and update reader globals',
      (tester) async {
    await _initPrefs(<String, Object>{});
    await _pumpPreferences(tester);

    tester.widget<Slider>(find.byType(Slider).at(0)).onChanged!(40);
    await tester.pumpAndSettle();
    expect(arabicFontSize, 40);
    expect(SP.prefs.getDouble('ara_font_size'), 40);

    tester.widget<Slider>(find.byType(Slider).at(1)).onChanged!(22);
    await tester.pumpAndSettle();
    expect(englishFontSize, 22);
    expect(SP.prefs.getDouble('eng_font_size'), 22);

    await _tapPreference(tester, 'Arabic Font');
    await tester.tap(find.text('Uthmani').last);
    await tester.pumpAndSettle();

    expect(arabicFont, 'Uthmani');
    expect(await FontPreferences.getSelectedFont(), 'Uthmani');
  });

  testWidgets('invalid saved Arabic font falls back to default',
      (tester) async {
    await _initPrefs(<String, Object>{'arabic_font': 'MissingFont'});

    expect(
        await FontPreferences.getSelectedFont(), FontPreferences.defaultFont);
    expect(SP.prefs.getString('arabic_font'), FontPreferences.defaultFont);
  });

  testWidgets('the old Show Reading Progress row is gone', (tester) async {
    await _initPrefs(<String, Object>{});
    await _pumpPreferences(tester);

    expect(find.text('Show Reading Progress'), findsNothing);
    expect(find.text('Focus mode'), findsOneWidget);
  });

  testWidgets('Focus mode defaults on with no prefs set at all',
      (tester) async {
    await _initPrefs(<String, Object>{});
    await _pumpPreferences(tester);

    expect(
      tester
          .widget<SwitchListTile>(find.ancestor(
            of: find.text('Focus mode'),
            matching: find.byType(SwitchListTile),
          ))
          .value,
      isTrue,
    );
  });

  testWidgets('Focus mode toggles and persists zikr_focus_mode',
      (tester) async {
    await _initPrefs(<String, Object>{});
    await _pumpPreferences(tester);

    await _tapPreference(tester, 'Focus mode');
    expect(SP.prefs.getBool(zikrFocusModeKey), isFalse);

    await _tapPreference(tester, 'Focus mode');
    expect(SP.prefs.getBool(zikrFocusModeKey), isTrue);
  });

  testWidgets(
      'a seeded show_zikr_progress: false renders Focus mode on, before '
      'the migration has run', (tester) async {
    await _initPrefs(<String, Object>{legacyShowZikrProgressKey: false});
    await _pumpPreferences(tester);

    expect(
      tester
          .widget<SwitchListTile>(find.ancestor(
            of: find.text('Focus mode'),
            matching: find.byType(SwitchListTile),
          ))
          .value,
      isTrue,
    );
  });

  testWidgets('translation flags hide and show reader content', (tester) async {
    await _initPrefs(<String, Object>{});
    const content = 'Transliteration line\nاللهم صل\nTranslation line';

    showTransliteration = false;
    showTranslation = true;
    await _pumpContentViewer(tester, content);

    expect(
      find.text('TRANSLITERATION LINE', findRichText: true),
      findsNothing,
    );
    expect(find.text('Translation line', findRichText: true), findsOneWidget);

    showTransliteration = true;
    showTranslation = false;
    await _pumpContentViewer(tester, content);

    expect(
      find.text('TRANSLITERATION LINE', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Translation line', findRichText: true), findsNothing);
  });
}

Future<void> _initPrefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  await SP.init();
}

Future<void> _pumpPreferences(
  WidgetTester tester, {
  VoidCallback? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ZikrReadingPreferencesControls(onChanged: onChanged),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapPreference(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _pumpContentViewer(WidgetTester tester, String content) async {
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
          code: '102',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void _resetReadingGlobals() {
  arabicFontSize = 32;
  englishFontSize = 16;
  arabicFont = FontPreferences.defaultFont;
  showTranslation = true;
  showTransliteration = true;
}
