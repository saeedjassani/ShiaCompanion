import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/navigation/app_shell.dart';
import 'package:shia_companion/theme/app_theme.dart';
import 'package:shia_companion/widgets/glass_surface.dart';

/// A tab root that counts its builds and keeps a counter in its state, so
/// the tests can tell "kept alive" from "rebuilt from scratch".
class _FakeTabPage extends StatefulWidget {
  const _FakeTabPage(this.name, this.created);

  final String name;
  final List<String> created;

  @override
  State<_FakeTabPage> createState() => _FakeTabPageState();
}

class _FakeTabPageState extends State<_FakeTabPage> {
  int taps = 0;

  @override
  void initState() {
    super.initState();
    widget.created.add(widget.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => setState(() => taps++),
          child: Text('${widget.name} page, $taps taps'),
        ),
      ),
    );
  }
}

class _Harness {
  final List<String> created = [];
  final List<String> selected = [];
  int searches = 0;

  List<AppShellTab> get tabs => [
        for (final name in ['Home', 'Quran', 'Favorites'])
          AppShellTab(
            label: name,
            icon: (color) => Icon(Icons.circle, color: color),
            builder: (_) => _FakeTabPage(name, created),
            onSelected: () => selected.add(name),
          ),
      ];

  Widget app({Brightness brightness = Brightness.light}) => MaterialApp(
        theme: buildAppTheme(brightness),
        home: AppShell(tabs: tabs, onSearch: () => searches++),
      );
}

Finder _tab(String label) =>
    find.bySemanticsLabel(RegExp('^$label, tab \\d of 3\$'));

void main() {
  testWidgets('shows the three tabs and the search button', (tester) async {
    final handle = tester.ensureSemantics();
    final h = _Harness();
    await tester.pumpWidget(h.app());

    expect(_tab('Home'), findsOneWidget);
    expect(_tab('Quran'), findsOneWidget);
    expect(_tab('Favorites'), findsOneWidget);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    expect(find.text('Home page, 0 taps'), findsOneWidget);

    expect(tester.getSemantics(_tab('Home')),
        isSemantics(isButton: true, isSelected: true));
    expect(tester.getSemantics(_tab('Quran')),
        isSemantics(isButton: true, isSelected: false));
    handle.dispose();
  });

  testWidgets('builds a tab on first visit, then keeps it alive',
      (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.app());
    expect(h.created, ['Home']);

    await tester.tap(find.text('Home page, 0 taps'));
    await tester.pump();

    await tester.tap(find.text('Quran'));
    await tester.pumpAndSettle();
    expect(h.created, ['Home', 'Quran']);
    expect(h.selected, ['Quran']);
    expect(find.text('Quran page, 0 taps'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    // Same state as before: not rebuilt, and Favorites still untouched.
    expect(find.text('Home page, 1 taps'), findsOneWidget);
    expect(h.created, ['Home', 'Quran']);
    expect(h.selected, ['Quran', 'Home']);
  });

  testWidgets('choosing the current tab again does nothing', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.app());

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(h.selected, isEmpty);
  });

  testWidgets('the search button opens search', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.app());

    await tester.tap(find.byTooltip('Search'));
    expect(h.searches, 1);
  });

  testWidgets('back on another tab returns to Home instead of leaving',
      (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.app());

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('Favorites page, 0 taps'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(find.text('Home page, 0 taps'), findsOneWidget);
  });

  testWidgets('the bar is only on the tab roots, not on pushed pages',
      (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.app());
    expect(find.byType(AppTabBar), findsOneWidget);

    Navigator.of(tester.element(find.text('Home page, 0 taps'))).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Pushed')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pushed'), findsOneWidget);
    expect(find.byType(AppTabBar), findsNothing);
  });

  testWidgets('tab roots get the bar as bottom padding', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.app());

    final padding =
        MediaQuery.paddingOf(tester.element(find.text('Home page, 0 taps')));
    expect(padding.bottom,
        greaterThanOrEqualTo(AppTabBar.height + AppTabBar.bottomGap));
  });

  group('layout', () {
    testWidgets('phone: full width less the gutters', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Harness().app());
      final search = tester.getRect(find.byTooltip('Search'));
      expect(search.width, AppTabBar.height);
      expect(search.right, 390 - AppTabBar.gutter);
      expect(search.bottom, 844 - AppTabBar.bottomGap);
    });

    testWidgets('tablet and up: a fixed-width group, centred', (tester) async {
      tester.view.physicalSize = const Size(820, 1180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Harness().app());
      final search = tester.getRect(find.byTooltip('Search'));
      const group =
          AppTabBar.wideBarWidth + AppTabBar.searchGap + AppTabBar.height;
      expect(search.right, closeTo((820 + group) / 2, 0.01));
    });

    testWidgets('stays clear of the system bottom inset', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Harness().app());
      final search = tester.getRect(find.byTooltip('Search'));
      expect(search.bottom, 844 - 48 - 8);
    });

    testWidgets('fits at 1.5x text in both themes', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(2.0),
          ),
          child: _Harness().app(brightness: brightness),
        ));
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('glass', () {
    testWidgets('blurs what is behind it by default', (tester) async {
      await tester.pumpWidget(_Harness().app());
      expect(
        find.descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(BackdropFilter)),
        findsWidgets,
      );
    });

    testWidgets('turns solid when the system asks for more contrast',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(highContrast: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

      await tester.pumpWidget(_Harness().app());
      expect(find.byType(GlassSurface), findsWidgets);
      expect(
        find.descendant(
            of: find.byType(GlassSurface),
            matching: find.byType(BackdropFilter)),
        findsNothing,
      );
    });
  });
}
