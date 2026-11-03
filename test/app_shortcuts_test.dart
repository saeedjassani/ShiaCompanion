import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/l10n/app_localizations.dart';
import 'package:shia_companion/l10n/app_localizations_en.dart';
import 'package:shia_companion/l10n/app_localizations_ur.dart';
import 'package:shia_companion/services/app_shortcuts_service.dart';

void main() {
  final AppLocalizations en = AppLocalizationsEn();

  group('AppShortcutsService.buildShortcuts', () {
    test('leads with Continue, then Favorites, Playlists and Tasbeeh', () {
      final items = AppShortcutsService.buildShortcuts(
        continueTitle: 'Dua Kumayl دعاء كميل',
        l10n: en,
        platform: TargetPlatform.android,
      );
      expect(items.map((item) => item.type), [
        'continue',
        'favorites',
        'playlists',
        'tasbeeh',
      ]);
      // Android has one line per shortcut, so the title goes in the label.
      expect(items.first.localizedTitle, 'Continue Dua Kumayl');
      expect(items.first.localizedSubtitle, isNull);
    });

    test('on iOS names the reading in the subtitle', () {
      final items = AppShortcutsService.buildShortcuts(
        continueTitle: '2: Al-Baqarah',
        l10n: en,
        platform: TargetPlatform.iOS,
      );
      expect(items.first.localizedTitle, 'Continue reading');
      expect(items.first.localizedSubtitle, '2: Al-Baqarah');
    });

    test('offers Qibla in place of Continue when there is nothing to continue',
        () {
      final items = AppShortcutsService.buildShortcuts(
        continueTitle: null,
        l10n: en,
        platform: TargetPlatform.android,
      );
      expect(items.map((item) => item.type), [
        'favorites',
        'playlists',
        'tasbeeh',
        'qibla',
      ]);
    });

    test('never offers more than four', () {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        for (final title in [null, 'Dua Nudba']) {
          expect(
            AppShortcutsService.buildShortcuts(
              continueTitle: title,
              l10n: en,
              platform: platform,
            ),
            hasLength(AppShortcutsService.maxShortcuts),
          );
        }
      }
    });

    test('labels follow the app language', () {
      final items = AppShortcutsService.buildShortcuts(
        continueTitle: 'دعائے کمیل',
        l10n: AppLocalizationsUr(),
        platform: TargetPlatform.android,
      );
      expect(items.first.localizedTitle, 'دعائے کمیل جاری رکھیں');
      expect(items[1].localizedTitle, AppLocalizationsUr().menuFavorites);
    });

    test('every shortcut has an icon named after it', () {
      final items = AppShortcutsService.buildShortcuts(
        continueTitle: 'Dua Kumayl',
        l10n: en,
        platform: TargetPlatform.android,
      );
      for (final item in items) {
        expect(item.icon, 'ic_shortcut_${item.type}');
      }
    });
  });

  group('AppShortcutsService.shortcutTitle', () {
    test('drops the Arabic after an English title', () {
      expect(AppShortcutsService.shortcutTitle('Dua Kumayl دعاء كميل'),
          'Dua Kumayl');
      expect(AppShortcutsService.shortcutTitle('36: Ya-Sin يس'), '36: Ya-Sin');
    });

    test('keeps a title written wholly in Arabic script', () {
      expect(AppShortcutsService.shortcutTitle('دعائے کمیل'), 'دعائے کمیل');
    });
  });

  test('shortcut ids are stable and resolve back', () {
    // A shortcut pinned to an Android home screen keeps its id; renaming one
    // would leave that pin doing nothing.
    expect(AppShortcut.values.map((s) => s.id),
        ['continue', 'favorites', 'playlists', 'tasbeeh', 'qibla']);
    for (final shortcut in AppShortcut.values) {
      expect(AppShortcut.fromId(shortcut.id), shortcut);
    }
    expect(AppShortcut.fromId('nope'), isNull);
  });
}
