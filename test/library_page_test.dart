import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/data/uid_title_data.dart';
import 'package:shia_companion/pages/chapter_list_page.dart';
import 'package:shia_companion/pages/library_page.dart';
import 'package:shia_companion/services/library_progress_store.dart';
import 'package:shia_companion/services/library_service.dart';
import 'package:shia_companion/utils/shared_preferences.dart';
import 'package:shia_companion/widgets/zikr_list_row.dart';

import 'ui/firebase_test_doubles.dart';

void main() {
  setUpAll(setUpFirebaseForRenderTests);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SP.init();
  });

  LibraryProgress progress({int chapterIndex = 3}) => LibraryProgress(
        bookSlug: 'man-and-his-destiny',
        bookTitle: 'Man and His Destiny',
        chapterSlug: 'part-2',
        chapterTitle: 'Part 2: Evil Effects',
        chapterIndex: chapterIndex,
        pageIndex: 3,
        pageCount: 9,
        fontSize: 18,
        updatedAt: DateTime(2026, 10, 1),
      );

  Future<void> pumpPushed(WidgetTester tester, Widget page) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Scaffold()));
    navigator.currentState!.push(MaterialPageRoute(builder: (_) => page));
    await tester.pumpAndSettle();
  }

  group('LibraryPage', () {
    testWidgets('counts the books and lists them with their authors',
        (tester) async {
      final books = await tester.runAsync(LibraryService.loadBooks);
      await pumpPushed(tester, LibraryPage());

      expect(find.textContaining(' books'), findsOneWidget);
      expect(find.text('ALL BOOKS'), findsOneWidget);
      expect(find.text('Request a book'), findsOneWidget);
      final withAuthor = books!.firstWhere((book) => book.author != null);
      await tester.enterText(find.byType(TextField), withAuthor.title);
      await tester.pumpAndSettle();
      expect(find.text(withAuthor.author!), findsWidgets);
    });

    testWidgets('finds a book by its author', (tester) async {
      final books = await tester.runAsync(LibraryService.loadBooks);
      final author = books!.firstWhere((book) => book.author != null).author!;
      await pumpPushed(tester, LibraryPage());

      await tester.enterText(find.byType(TextField), author);
      await tester.pumpAndSettle();

      expect(find.byType(ZikrListRow), findsWidgets);
      for (final row in tester.widgetList<ZikrListRow>(
          find.byType(ZikrListRow))) {
        expect(row.subtitle, contains(author));
      }
    });

    testWidgets('offers a request when nothing matches', (tester) async {
      await pumpPushed(tester, LibraryPage());

      await tester.enterText(find.byType(TextField), 'zzqqxx');
      await tester.pumpAndSettle();

      expect(find.byType(ZikrListRow), findsNothing);
      expect(find.text('Nothing called “zzqqxx” here'), findsOneWidget);
      expect(find.text('Request a book'), findsNWidgets(2));
    });

    testWidgets('shows where the reader left off, and forgets it on ×',
        (tester) async {
      await LibraryProgressStore.instance.save(progress());
      await pumpPushed(tester, LibraryPage());

      expect(find.text('Continue reading'), findsOneWidget);
      expect(find.text('Man and His Destiny'), findsOneWidget);
      expect(find.text('Part 2: Evil Effects · page 4 of 9'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(
          'Remove Man and His Destiny from Continue reading'));
      await tester.pumpAndSettle();

      expect(find.text('Continue reading'), findsNothing);
      expect(LibraryProgressStore.instance.readAll(), isEmpty);
    });
  });

  group('ChapterListPage', () {
    final chapters = [
      UidTitleData('biography', 'Short Biography of the Author'),
      UidTitleData('prologue', 'Prologue'),
      UidTitleData('part-1', 'Part 1: Fate and Destiny'),
      UidTitleData('part-2', 'Part 2: Evil Effects'),
      UidTitleData('part-3', 'Part 3: Onslaught'),
    ];

    setUp(() => LibraryService.seedChaptersForTesting(
        'man-and-his-destiny', chapters));

    testWidgets('a book not yet started offers to start it', (tester) async {
      await pumpPushed(
          tester,
          const ChapterListPage(
              'man-and-his-destiny', 'Man and His Destiny'));

      expect(find.text('Start reading'), findsOneWidget);
      expect(find.text('Save for offline'), findsOneWidget);
      expect(find.text('CHAPTERS'), findsOneWidget);
      expect(find.textContaining('5 chapters'), findsOneWidget);
      expect(find.textContaining('Reading ·'), findsNothing);
    });

    testWidgets('a started book continues where the reader left off',
        (tester) async {
      await LibraryProgressStore.instance.save(progress());
      await pumpPushed(
          tester,
          const ChapterListPage(
              'man-and-his-destiny', 'Man and His Destiny'));

      expect(find.text('Continue · chapter 4, page 4'), findsOneWidget);
      expect(find.text('Reading · page 4 of 9'), findsOneWidget);
    });

    testWidgets('finds the current chapter by slug if chapters moved',
        (tester) async {
      await LibraryProgressStore.instance.save(progress(chapterIndex: 0));
      await pumpPushed(
          tester,
          const ChapterListPage(
              'man-and-his-destiny', 'Man and His Destiny'));

      expect(find.text('Continue · chapter 4, page 4'), findsOneWidget);
    });
  });
}
