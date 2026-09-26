import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shia_companion/utils/app_text_scale.dart';
import 'package:shia_companion/utils/shared_preferences.dart';

void main() {
  group('normalize', () {
    test('clamps to the supported range', () {
      expect(
          AppTextScaleProvider.normalize(0.1), AppTextScaleProvider.minScale);
      expect(AppTextScaleProvider.normalize(9), AppTextScaleProvider.maxScale);
    });

    test('snaps to the nearest 5% slider stop', () {
      expect(AppTextScaleProvider.normalize(1.12), 1.1);
      expect(AppTextScaleProvider.normalize(1.13), 1.15);
      expect(AppTextScaleProvider.normalize(1.0), 1.0);
    });
  });

  group('AppTextScaler', () {
    test('multiplies the system scaler rather than replacing it', () {
      const scaler = AppTextScaler(TextScaler.linear(1.2), 1.5);
      expect(scaler.scale(10), closeTo(18, 1e-9));
    });

    test('clamp bounds the combined scale, not just the system part', () {
      final clamped = const AppTextScaler(TextScaler.linear(1.2), 1.5).clamp(
        maxScaleFactor: 1.5,
      );
      expect(clamped.scale(10), closeTo(15, 1e-9));
    });
  });

  group('AppTextScaleProvider', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SP.init();
    });

    test('loads a saved scale, normalized', () async {
      SharedPreferences.setMockInitialValues(
          {AppTextScaleProvider.prefsKey: 1.27});
      final provider = AppTextScaleProvider();
      await pumpEventQueue();
      expect(provider.scale, 1.25);
    });

    test('save persists the current scale', () async {
      final provider = AppTextScaleProvider();
      await pumpEventQueue();
      provider.setScale(1.3);
      await provider.save();
      expect(SP.prefs.getDouble(AppTextScaleProvider.prefsKey), 1.3);
    });

    testWidgets('apply scales text under it on top of the system scale',
        (tester) async {
      final provider = AppTextScaleProvider();
      await tester.pump();
      provider.setScale(1.5);

      late TextScaler seen;
      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Builder(
          builder: (context) => provider.apply(
            context,
            Builder(builder: (context) {
              seen = MediaQuery.textScalerOf(context);
              return const SizedBox();
            }),
          ),
        ),
      ));

      expect(seen.scale(10), closeTo(30, 1e-9));
    });
  });
}
