import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/data/whats_new_notes.dart';
import 'package:shia_companion/widgets/whats_new_dialog.dart';

void main() {
  const older = WhatsNewEntry(
    buildNumber: 100,
    versionName: '1.0.0',
    bullets: ['older bullet'],
  );
  const newer = WhatsNewEntry(
    buildNumber: 105,
    versionName: '1.0.5',
    bullets: ['newer bullet'],
  );

  Future<void> open(WidgetTester tester, List<WhatsNewEntry> entries) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showWhatsNewDialog(context, entries),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a single release is titled with its version', (tester) async {
    await open(tester, [newer]);

    expect(find.text("What's new in 1.0.5"), findsOneWidget);
    expect(find.text('newer bullet'), findsOneWidget);
    expect(find.text('Version 1.0.5'), findsNothing);
  });

  testWidgets('several releases get one heading per version', (tester) async {
    await open(tester, [older, newer]);

    expect(find.text("What's new"), findsOneWidget);
    expect(find.text('Version 1.0.0'), findsOneWidget);
    expect(find.text('Version 1.0.5'), findsOneWidget);
    expect(find.text('older bullet'), findsOneWidget);
    expect(find.text('newer bullet'), findsOneWidget);
  });

  testWidgets('Got it dismisses the dialog', (tester) async {
    await open(tester, [newer]);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('shows nothing when there are no entries', (tester) async {
    await open(tester, const []);

    expect(find.byType(AlertDialog), findsNothing);
  });
}
