import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/azaan_option.dart';

void main() {
  test('all option ids are unique', () {
    final ids = AzaanOptions.all.map((option) => option.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('getById finds a known option and returns null for an unknown id', () {
    expect(AzaanOptions.getById('takbir'), same(AzaanOptions.takbir));
    expect(AzaanOptions.getById('custom'), same(AzaanOptions.custom));
    expect(AzaanOptions.getById('does-not-exist'), isNull);
  });

  test('getDefault returns the full azaan option', () {
    expect(AzaanOptions.getDefault(), same(AzaanOptions.azaan));
  });

  test('only the custom option is flagged as custom', () {
    expect(AzaanOptions.custom.isCustom, isTrue);
    for (final option in AzaanOptions.all.where((o) => o.id != 'custom')) {
      expect(option.isCustom, isFalse, reason: option.id);
    }
  });

  test('systemDefault has no bundled sound files', () {
    expect(AzaanOptions.systemDefault.androidFile, isNull);
    expect(AzaanOptions.systemDefault.iosFile, isNull);
  });

  test('Full Azan tells iOS users to tap, and other platforms nothing extra',
      () {
    final ios = AzaanOptions.azaan.descriptionFor(isIOS: true);
    expect(ios, contains('tap'));
    expect(ios, isNot(contains('Android')));
    expect(AzaanOptions.azaan.descriptionFor(isIOS: false),
        AzaanOptions.azaan.description);
  });

  test('options without an iOS description use the shared one on iOS', () {
    for (final option
        in AzaanOptions.all.where((o) => o.iosDescription == null)) {
      expect(option.descriptionFor(isIOS: true), option.description,
          reason: option.id);
    }
  });
}
