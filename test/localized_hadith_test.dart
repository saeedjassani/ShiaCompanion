import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/home/hadith_card.dart';
import 'package:shia_companion/utils/localized_hadith.dart';

void main() {
  final json = jsonDecode(File(localizedHadithAsset).readAsStringSync())
      as Map<String, dynamic>;
  final collection = LocalizedHadithCollection.fromJson(json);

  test('every hadith has its Arabic, translations and source', () {
    final ids = <String>{};
    for (final item in json['hadith'] as List) {
      final id = item['id'] as String;
      expect(ids.add(id), isTrue, reason: 'duplicate $id');
      expect(collection.speakers, contains(item['speaker']), reason: id);
      for (final code in ['ar', 'ur', 'fa']) {
        expect((item[code] as String).trim(), isNotEmpty, reason: '$id $code');
        expect((item['source'][code] as String).trim(), isNotEmpty,
            reason: '$id source $code');
      }
      // The attribution is drawn from the speaker, never repeated in the text.
      expect(item['ar'], isNot(startsWith('قال')), reason: id);
    }
    expect(collection.general, isNotEmpty);
  });

  test('every speaker is attributed in every language', () {
    for (final entry in collection.speakers.entries) {
      for (final code in ['ar', 'ur', 'fa']) {
        expect(entry.value[code], isNotEmpty, reason: '${entry.key} $code');
      }
    }
  });

  test('Arabic shows the Arabic alone; Urdu and Persian translate it', () {
    final arabic = collection.pick('ar', useMuharramQuotes: false, day: 20000)!;
    expect(arabic.translation, isNull);
    expect(arabic.attribution, startsWith('قال'));
    expect(arabic.shareText, contains(arabic.arabic));

    for (final code in ['ur', 'fa']) {
      final hadith =
          collection.pick(code, useMuharramQuotes: false, day: 20000)!;
      expect(hadith.arabic, arabic.arabic, reason: 'same hadith that day');
      expect(hadith.translation, isNotEmpty);
      expect(hadith.shareText, contains(hadith.translation!));
      expect(hadith.shareText, contains(hadith.source));
    }
  });

  test('English and Gujarati have no translation, so keep their own', () {
    expect(collection.pick('en', useMuharramQuotes: false, day: 1), isNull);
    expect(collection.pick('gu', useMuharramQuotes: false, day: 1), isNull);
  });

  test('without Muharram hadith, Muharram days show the general ones', () {
    final hadith = collection.pick('ur', useMuharramQuotes: true, day: 20000);
    expect(hadith, isNotNull);
  });

  test('a hadith does not repeat until every one has been shown', () {
    final count = collection.general.length;
    final seen = {
      for (var day = 20000; day < 20000 + count; day++)
        collection.pick('ar', useMuharramQuotes: false, day: day)!.arabic,
    };
    expect(seen, hasLength(count));
  });

  testWidgets('the card shows the Arabic, translation and source', (
    tester,
  ) async {
    const hadith = LocalizedHadith(
      languageCode: 'ur',
      arabic: 'اسْتَنْزِلُوا الرِّزْقَ بِالصَّدَقَةِ.',
      attribution: 'امیر المومنین (ع) نے فرمایا',
      translation: 'صدقہ کے ذریعہ روزی طلب کرو۔',
      source: 'نہج البلاغہ، حکمت 137',
    );
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: HadithOfTheDayCard(localized: hadith)),
    ));
    expect(find.text(hadith.arabic), findsOneWidget);
    expect(find.textContaining(hadith.translation!, findRichText: true),
        findsOneWidget);
    expect(find.text(hadith.source), findsOneWidget);
  });
}
