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
      // Gujarati covers only some: where it does, with its reference too.
      expect(item['gu'] == null, item['source']['gu'] == null, reason: id);
      if (item['gu'] != null) {
        expect((item['gu'] as String).trim(), isNotEmpty, reason: '$id gu');
        expect((item['source']['gu'] as String).trim(), isNotEmpty,
            reason: '$id source gu');
        expect(RegExp('[A-Za-z]').hasMatch(item['gu'] + item['source']['gu']),
            isFalse,
            reason: '$id gu has no English');
      }
      // The attribution is drawn from the speaker, never repeated in the text.
      expect(item['ar'], isNot(startsWith('قال')), reason: id);
    }
    expect(collection.general, isNotEmpty);
  });

  test('every speaker is attributed in every language they are read in', () {
    for (final entry in collection.speakers.entries) {
      for (final code in ['ar', 'ur', 'fa']) {
        expect(entry.value[code], isNotEmpty, reason: '${entry.key} $code');
      }
    }
    for (final item in json['hadith'] as List) {
      if (item['gu'] != null) {
        expect(collection.speakers[item['speaker']]!['gu'], isNotEmpty,
            reason: '${item['speaker']} gu');
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

  test('English has no translation here, so keeps its own', () {
    expect(collection.pick('en', useMuharramQuotes: false, day: 1), isNull);
  });

  test('Gujarati is only ever shown the hadith translated into it', () {
    final translated = {
      for (final item in json['hadith'] as List)
        if (item['gu'] != null) item['gu'] as String,
    };
    expect(translated, isNotEmpty);
    expect(collection.covers('gu'), isTrue);
    final seen = <String>{};
    for (var day = 20000; day < 20000 + translated.length; day++) {
      for (final muharram in [false, true]) {
        final hadith =
            collection.pick('gu', useMuharramQuotes: muharram, day: day)!;
        expect(translated, contains(hadith.translation));
        expect(hadith.attribution, isNotEmpty);
        expect(hadith.source, isNotEmpty);
        expect(RegExp('[A-Za-z]').hasMatch(hadith.shareText), isFalse);
        if (!muharram) seen.add(hadith.translation!);
      }
    }
    expect(seen, translated, reason: 'each shown once before any repeats');
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
