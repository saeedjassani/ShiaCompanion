import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/services/mistake_report_service.dart';

void main() {
  group('MistakeReport.fromMap', () {
    test('reads every field back out of the stored document', () {
      final createdAt = DateTime.utc(2026, 9, 21, 14, 30);
      final report = MistakeReport.fromMap('report1', {
        'zikrUid': 'A36',
        'zikrTitle': '32: As-Sajda',
        'selectedText': 'الٓمٓ',
        'note': 'Missing a word here',
        'status': 'open',
        'createdAt': Timestamp.fromDate(createdAt),
      });

      expect(report.id, 'report1');
      expect(report.zikrUid, 'A36');
      expect(report.zikrTitle, '32: As-Sajda');
      expect(report.selectedText, 'الٓمٓ');
      expect(report.note, 'Missing a word here');
      expect(report.status, 'open');
      // Timestamp.toDate() hands back local-clock wall time for the same
      // instant, not a DateTime flagged isUtc - compare the instant, not the
      // flag.
      expect(report.createdAt?.isAtSameMomentAs(createdAt), isTrue);
      expect(report.isResolved, isFalse);
    });

    test('isResolved reflects the stored status', () {
      final report = MistakeReport.fromMap('report2', {'status': 'resolved'});
      expect(report.isResolved, isTrue);
    });

    test('missing fields decode defensively instead of throwing', () {
      final report = MistakeReport.fromMap('report3', const {});

      expect(report.zikrUid, '');
      expect(report.zikrTitle, '');
      expect(report.selectedText, '');
      expect(report.note, '');
      // A report with no recorded status is treated as still open, not lost
      // from the queue an admin actually looks at.
      expect(report.status, 'open');
      expect(report.isResolved, isFalse);
      expect(report.createdAt, isNull);
    });
  });
}
