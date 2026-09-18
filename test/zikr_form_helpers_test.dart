import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_form_helpers.dart';

void main() {
  test('visible tab helper keeps primary only when it should render', () {
    expect(
      buildVisibleZikrTabContents(primary: 'Primary', extraTabs: const []),
      ['Primary'],
    );
    expect(
      buildVisibleZikrTabContents(primary: '', extraTabs: const []),
      [''],
    );
    expect(
      buildVisibleZikrTabContents(
        primary: '',
        extraTabs: [' ', 'Tab 2'],
      ),
      ['Tab 2'],
    );
    expect(
      buildVisibleZikrTabContents(
        primary: 'Primary',
        extraTabs: ['Tab 2', ' '],
      ),
      ['Primary', 'Tab 2'],
    );
  });
}
