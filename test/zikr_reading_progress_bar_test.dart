import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/widgets/zikr_reading_progress_bar.dart';

const Size _smallPhone = Size(320, 640);

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MediaQuery(
    data: const MediaQueryData(size: _smallPhone),
    child: MaterialApp(
      theme: ThemeData(brightness: brightness, useMaterial3: true),
      home: Scaffold(
        body: Stack(
          children: [Positioned(left: 0, right: 0, top: 0, child: child)],
        ),
      ),
    ),
  );
}

void main() {
  group('ZikrReadingProgressBar', () {
    testWidgets('renders both labels without overflowing a narrow phone',
        (t) async {
      await t.pumpWidget(_host(const ZikrReadingProgressBar(
        progress: 0.42,
        readingTimeLabel: '7 min read',
        progressLabel: '42%',
      )));

      expect(find.text('7 min read'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      // A RenderFlex overflow surfaces as a thrown exception, so this is what
      // catches the strip being too cramped for both labels at once.
      expect(t.takeException(), isNull);
    });

    testWidgets('height matches barHeight plus its divider', (t) async {
      await t.pumpWidget(_host(const ZikrReadingProgressBar(
        progress: 0.5,
        readingTimeLabel: '7 min read',
        progressLabel: '50%',
      )));

      final height = t.getSize(find.byType(ZikrReadingProgressBar)).height;
      // The content's top inset is padded by exactly barHeight — if the
      // strip's real height drifted from that constant, the first line of
      // text would end up either hidden behind it or with a gap above it.
      expect(height, ZikrReadingProgressBar.barHeight + 1);
    });

    testWidgets('passes progress straight through to the indicator', (t) async {
      await t.pumpWidget(_host(const ZikrReadingProgressBar(
        progress: 0.73,
        readingTimeLabel: '7 min read',
        progressLabel: '73%',
      )));

      final indicator = t.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(indicator.value, 0.73);
    });

    testWidgets('paints an opaque surface so reading text cannot show through',
        (t) async {
      await t.pumpWidget(_host(const ZikrReadingProgressBar(
        progress: 0.1,
        readingTimeLabel: '7 min read',
        progressLabel: '10%',
      )));

      final material = t.widget<Material>(find
          .descendant(
            of: find.byType(ZikrReadingProgressBar),
            matching: find.byType(Material),
          )
          .first);
      expect(material.color, isNotNull);
      expect(material.color, isNot(Colors.transparent));
    });

    for (final brightness in Brightness.values) {
      testWidgets('renders without exception in $brightness', (t) async {
        await t.pumpWidget(_host(
          const ZikrReadingProgressBar(
            progress: 0.6,
            readingTimeLabel: '7 min read',
            progressLabel: '60%',
          ),
          brightness: brightness,
        ));

        expect(t.takeException(), isNull);
      });
    }
  });
}
