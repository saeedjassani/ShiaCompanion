import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/l10n/app_language.dart';
import 'package:shia_companion/pages/zikr/zikr_content_parser.dart';
import 'package:shia_companion/pages/zikr/zikr_sections.dart';
import 'package:shia_companion/services/zikr_translations.dart';

const _verse = 'اَللّٰهُمَّ اِنِّیْٓ اَسْئَلُكَ بِاسْمِكَ یَا اَللهُ';
const _translit = 'ALLAAHUMMA INNEE AS-ALOKA BISMEKA YAA ALLAAHO';
const _translation = 'O Allah I beseech You in Your name, O Allah';

String _content() => [
      'At the end of each section, recite:',
      '## Section 1: For Success',
      _verse,
      _translit,
      _translation,
      '## Section 2: To Seek Help',
      _verse,
      _translit,
      _translation,
    ].join('\n');

void main() {
  group('section headings', () {
    test('a ## line is a heading, read without its marker', () {
      final parsed =
          ZikrContentParser.parseContent(_content(), hideHeaderLine: false);
      expect(parsed.headingLines, {1, 5});
      expect(parsed.lines[1], 'Section 1: For Success');
      // Still a standalone line, numbered as a segment like any other.
      expect(parsed.arabicCodes.contains(1), isFalse);
      expect(parsed.segments.map((s) => s.anchorLine), [0, 1, 2, 5, 6]);
    });

    test('the marker never reaches the screen through a link span', () {
      final spans =
          ZikrContentParser.parseLineSegments('## Recite [Dua Kumayl](E31)');
      expect(spans.map((s) => s.text).join(), 'Recite Dua Kumayl');
    });

    test('lists the sections in reading order', () {
      final parsed =
          ZikrContentParser.parseContent(_content(), hideHeaderLine: false);
      expect(zikrSectionsOf(parsed), const [
        ZikrSection(lineIndex: 1, label: 'Section 1: For Success'),
        ZikrSection(lineIndex: 5, label: 'Section 2: To Seek Help'),
      ]);
    });

    test(
        'outside English, labels are translated and untranslated ones left out',
        () {
      final english =
          ZikrContentParser.parseContent(_content(), hideHeaderLine: false);
      final urdu = appLanguageFor('ur')!;
      // Segments: 0 the instruction, 1 Section 1, 2 its verse, 3 Section 2.
      final parsed = english.localizedTo(
        urdu,
        ZikrDocumentTranslation(language: urdu, segments: {1: 'حصہ 1'}),
        firstSegment: 0,
      );
      expect(zikrSectionsOf(parsed), const [
        ZikrSection(lineIndex: 1, label: 'حصہ 1'),
      ]);
    });

    test('the section being read is the last heading at or above the top line',
        () {
      const sections = [
        ZikrSection(lineIndex: 1, label: 'One'),
        ZikrSection(lineIndex: 5, label: 'Two'),
      ];
      expect(zikrSectionAt(sections, null), isNull);
      expect(zikrSectionAt(sections, 0), isNull);
      expect(zikrSectionAt(sections, 1)?.label, 'One');
      expect(zikrSectionAt(sections, 4)?.label, 'One');
      expect(zikrSectionAt(sections, 7)?.label, 'Two');
    });
  });

  group('ZikrSectionsController', () {
    test('notifies only when the sections change, and forwards a jump',
        () async {
      final controller = ZikrSectionsController();
      var notified = 0;
      controller.addListener(() => notified++);
      const sections = [ZikrSection(lineIndex: 3, label: 'A')];
      controller.setSections(sections);
      controller.setSections(const [ZikrSection(lineIndex: 3, label: 'A')]);
      expect(notified, 1);

      int? jumpedTo;
      Future<void> jump(int line) async => jumpedTo = line;
      controller.attach(jump);
      await controller.jumpTo(3);
      expect(jumpedTo, 3);

      controller.detach(jump);
      jumpedTo = null;
      await controller.jumpTo(3);
      expect(jumpedTo, isNull);
    });
  });
}
