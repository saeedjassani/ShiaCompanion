import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/services/content_request_service.dart';
import 'package:shia_companion/widgets/content_request_dialog.dart';

void main() {
  group('ContentRequest.fromMap', () {
    test('reads every field back out of the stored document', () {
      final createdAt = DateTime.utc(2026, 10, 2, 9, 15);
      final request = ContentRequest.fromMap('req1', {
        'type': 'book',
        'title': 'Nahj al-Balagha',
        'details': 'Sayed Ali Reza translation',
        'status': 'open',
        'createdAt': Timestamp.fromDate(createdAt),
      });

      expect(request.id, 'req1');
      expect(request.type, ContentRequestType.book);
      expect(request.title, 'Nahj al-Balagha');
      expect(request.details, 'Sayed Ali Reza translation');
      expect(request.createdAt?.isAtSameMomentAs(createdAt), isTrue);
      expect(request.isResolved, isFalse);
    });

    test('isResolved reflects the stored status', () {
      final request = ContentRequest.fromMap('req2', {'status': 'resolved'});
      expect(request.isResolved, isTrue);
    });

    test('missing or unknown fields decode defensively', () {
      final request = ContentRequest.fromMap('req3', {'type': 'video'});

      expect(request.type, ContentRequestType.zikr);
      expect(request.title, '');
      expect(request.details, '');
      expect(request.status, 'open');
      expect(request.createdAt, isNull);
    });
  });

  group('ContentRequestDialog', () {
    /// Opens the dialog from a button and reports what it popped with.
    Future<void> openDialog(
      WidgetTester tester, {
      String initialTitle = '',
      void Function(ContentRequestDraft?)? onClosed,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showDialog<ContentRequestDraft>(
                context: context,
                builder: (_) =>
                    ContentRequestDialog(initialTitle: initialTitle),
              );
              onClosed?.call(result);
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('Send stays disabled until a title is entered', (tester) async {
      await openDialog(tester);

      FilledButton send() => tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Send'));
      expect(send().onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.pump();
      expect(send().onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'Dua Mashlool');
      await tester.pump();
      expect(send().onPressed, isNotNull);
    });

    testWidgets('returns the trimmed draft with the chosen type',
        (tester) async {
      ContentRequestDraft? result;
      await openDialog(tester,
          initialTitle: 'kamil ', onClosed: (draft) => result = draft);

      await tester.tap(find.text('Book'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).last, ' Kamil al-Ziyarat ');
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      expect(result?.type, ContentRequestType.book);
      expect(result?.title, 'kamil');
      expect(result?.details, 'Kamil al-Ziyarat');
    });
  });
}
