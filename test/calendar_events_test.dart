import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/utils/calendar_events.dart';
import 'package:shia_companion/utils/islamic_calendar_widget_data.dart';

/// Serves the real assets from disk, like the app's bundle.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final file = File(key);
    if (!file.existsSync()) throw StateError('missing asset $key');
    return ByteData.sublistView(await file.readAsBytes());
  }
}

void main() {
  final english =
      json.decode(File('assets/events.json').readAsStringSync()) as Map;

  group('translateEvents', () {
    test('lays content and title over a translated day, keeps the colour', () {
      final events = CalendarEvents.translateEvents(
        {
          '02-07': {'content': 'Birth of Imam Moosa', 'color': 1},
          '02-10': {'content': 'Martyrdom', 'color': 0},
        },
        {
          '02-07': {'content': 'ولادة الإمام', 'title': ' ولادة '},
        },
      );
      expect(events['02-07'],
          {'content': 'ولادة الإمام', 'color': 1, 'title': 'ولادة'});
      expect(events['02-10'], {'content': 'Martyrdom', 'color': 0});
    });

    test('ignores a translation with no content', () {
      final events = CalendarEvents.translateEvents(
        {
          '02-07': {'content': 'Birth', 'color': 1},
        },
        {
          '02-07': {'content': ' ', 'title': 'ولادة'},
        },
      );
      expect(events['02-07'], {'content': 'Birth', 'color': 1});
    });
  });

  group('eventHeadline', () {
    test('a translated day shows its title whole, with no kind', () {
      final text = eventHeadline({
        'content': 'ولادة الإمام موسى الكاظم (ع)، الإمام السابع (128 هـ)',
        'title': 'ولادة الإمام موسى الكاظم (ع)',
      });
      expect(text.name, 'ولادة الإمام موسى الكاظم (ع)');
      expect(text.shortName, text.name);
      expect(text.kind, isEmpty);
    });

    test('an English day is cut out of its content as before', () {
      final text = eventHeadline({
        'content':
            'Birth of Imam Moosa al‐Kazim(a.s.) – the 7th Holy Imam ‐ (128 A.H.)',
      });
      expect(text.kind, 'Birth');
    });
  });

  for (final code in ['ar', 'ur', 'fa', 'gu']) {
    test('$code translates every day of events.json, line for line', () async {
      final translations =
          json.decode(File('assets/events_i18n/$code.json').readAsStringSync())
              as Map;
      expect(translations.keys.toList(), english.keys.toList());
      for (final key in english.keys) {
        final source = english[key]['content'] as String;
        final translated = translations[key] as Map;
        final content = translated['content'] as String;
        final title = translated['title'] as String;
        expect(title.trim(), isNotEmpty, reason: '$code $key title');
        expect(title, isNot(contains('\n')), reason: '$code $key title');
        expect(
          '\n\n'.allMatches(content).length,
          '\n\n'.allMatches(source).length,
          reason: '$code $key keeps its paragraphs',
        );
        expect(RegExp('[A-Za-z]').hasMatch(content + title), isFalse,
            reason: '$code $key has no English left');
      }
    });

    test('$code loads through CalendarEvents', () async {
      final events =
          await CalendarEvents.load(languageCode: code, bundle: _DiskBundle());
      expect(events.length, english.length);
      final first = events[english.keys.first] as Map;
      expect(first['title'], isNotEmpty);
      expect(first['color'], english[english.keys.first]['color']);
    });
  }

  test('English loads events.json unchanged', () async {
    final events =
        await CalendarEvents.load(languageCode: 'en', bundle: _DiskBundle());
    expect(events, english);
  });
}
