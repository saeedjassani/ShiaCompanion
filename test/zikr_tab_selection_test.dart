import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/constants.dart';
import 'package:shia_companion/data/retired_zikr_redirects.dart';
import 'package:shia_companion/l10n/app_language.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';
import 'package:shia_companion/pages/zikr/zikr_form_helpers.dart';
import 'package:shia_companion/pages/zikr/zikr_tab_selection.dart';
import 'package:shia_companion/services/zikr_translations.dart';

/// The tabs the reader shows for content file `assets/zikr/<uid>`.
List<String> readerTabsOf(String uid) {
  final document =
      json.decode(File('assets/zikr/$uid').readAsStringSync()) as Map;
  final tabs = document['tabs'];
  return buildVisibleZikrTabContents(
    primary: document['data']?.toString() ?? '',
    extraTabs: tabs is List ? tabs.map((tab) => '$tab') : const <String>[],
  );
}

/// Each tab's verses, as (Arabic line, its translation) pairs, numbered the
/// way [ZikrContentParser.segmentOffsets] numbers them - and the tab's label
/// translation first, where there is a tab strip to show it.
List<List<(String, String?)>> versesByTab(
  List<String> tabs,
  ZikrDocumentTranslation translation,
) {
  final hasHeaders = tabs.length > 1;
  final offsets = ZikrContentParser.segmentOffsets(tabs);
  return [
    for (var i = 0; i < tabs.length; i++)
      () {
        final parsed =
            ZikrContentParser.parseContent(tabs[i], hideHeaderLine: hasHeaders);
        final first = offsets[i] + (hasHeaders ? 1 : 0);
        return [
          if (hasHeaders) ('label', translation.segment(offsets[i])),
          for (var k = 0; k < parsed.segments.length; k++)
            if (parsed.arabicCodes.contains(parsed.segments[k].anchorLine))
              (
                parsed.lines[parsed.segments[k].anchorLine],
                translation.segment(first + k),
              ),
        ];
      }(),
  ];
}

void main() {
  tearDown(() => itemTabs = {});

  group('shownZikrTabs', () {
    test('an alias names its tabs from 1, as the reader and links do', () {
      itemTabs = {
        'ZZ1|I24': [2, 4]
      };
      expect(shownZikrTabs('ZZ1|I24'), [1, 3]);
    });

    test('a retired uid names tabs[] indexes, past the main data', () {
      expect(retiredZikrRedirects['E50']!.tabs, [2, 3]);
      expect(shownZikrTabs('E50'), [3, 4]);
    });

    test('anything else shows its whole content', () {
      expect(shownZikrTabs('I24'), isNull);
      expect(shownZikrTabs('R11|G4'), isNull);
      // Lands on a tab, but still shows them all.
      expect(shownZikrTabs('I26'), isNull);
    });
  });

  test('effectiveShownZikrTabs drops tabs that do not exist', () {
    expect(effectiveShownZikrTabs([3, 4], 6), [3, 4]);
    expect(effectiveShownZikrTabs([3, 9, 3], 6), [3]);
    expect(effectiveShownZikrTabs([9], 6), isNull);
    expect(effectiveShownZikrTabs(null, 6), isNull);
  });

  group('shownZikrTabContents', () {
    const tabs = ['First\nOne', 'Second\nTwo', 'Third\nThree'];

    test('keeps each tab whole while there is still a tab strip', () {
      expect(
          shownZikrTabContents(tabs, [2, 0]), ['Third\nThree', 'First\nOne']);
    });

    test('drops a lone tab\'s label line, which the strip used to carry', () {
      expect(shownZikrTabContents(tabs, [1]), ['Two']);
      expect(shownZikrTabContents(['Only\nOne'], [0]), ['Only\nOne']);
    });
  });

  group('translationForShownZikrTabs keeps every verse its translation', () {
    final urdu = appLanguageFor('ur')!;

    for (final uid in ['I24', 'AK5', 'D3']) {
      test(uid, () {
        final translation = ZikrDocumentTranslation.fromJson(
          urdu,
          json.decode(File('assets/zikr_i18n/ur/$uid.json').readAsStringSync()),
        );
        final allTabs = readerTabsOf(uid);
        final whole = versesByTab(allTabs, translation);
        expect(
            whole.expand((tab) => tab).any((verse) => verse.$2 != null), isTrue,
            reason: '$uid should have translated verses to check');

        final selections = [
          for (var i = 0; i < allTabs.length; i++) [i],
          [for (var i = allTabs.length - 1; i >= 0; i -= 2) i],
          [1, 2],
        ];
        for (final shown in selections) {
          final shownTabs = shownZikrTabContents(allTabs, shown);
          final part = versesByTab(
            shownTabs,
            translationForShownZikrTabs(translation, allTabs, shown),
          );
          for (var j = 0; j < shown.length; j++) {
            final expected = [
              for (final verse in whole[shown[j]])
                if (shownTabs.length > 1 || verse.$1 != 'label') verse,
            ];
            expect(part[j], expected, reason: '$uid tabs $shown, tab $j');
          }
        }
      });
    }
  });

  group('every tab reference in the corpus names a tab that exists', () {
    test('zikr.json aliases', () {
      final index = json.decode(File('assets/zikr.json').readAsStringSync())
          as Map<String, dynamic>;
      for (final entry in index.entries) {
        final tabs = (entry.value as Map)['tabs'];
        if (tabs == null) continue;
        expect(entry.key, contains('|'),
            reason: 'only an alias can stand for some tabs');
        final target = entry.key.split('|').last;
        final count = readerTabsOf(target).length;
        expect(tabs, isA<List>());
        expect(tabs, isNotEmpty, reason: entry.key);
        for (final number in tabs as List) {
          expect(number, isA<int>(), reason: entry.key);
          expect(number, inInclusiveRange(1, count), reason: entry.key);
        }
      }
    });

    test('retired redirects', () {
      for (final entry in retiredZikrRedirects.entries) {
        final redirect = entry.value;
        final document = json.decode(
            File('assets/zikr/${redirect.targetUid}').readAsStringSync());
        final tabs = (document['tabs'] as List?) ?? const [];
        if (redirect.tabIndex != null || redirect.tabs != null) {
          // `tabs[i]` is the reader's tab i + 1 only while `data` shows.
          expect('${document['data'] ?? ''}'.trim(), isNotEmpty,
              reason: '${entry.key}: ${redirect.targetUid} has no data');
        }
        for (final i in [
          if (redirect.tabIndex != null) redirect.tabIndex!,
          ...?redirect.tabs,
        ]) {
          expect(i, inInclusiveRange(0, tabs.length - 1), reason: entry.key);
        }
      }
    });
  });
}
