import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/pages/zikr/zikr_form_helpers.dart';

void main() {
  test('day helpers round trip single and multiple patterns', () {
    expect(formatZikrDayValue('09-09'), '09-09');
    expect(formatZikrDayValue(['09-09', '10-*-0']), '09-09, 10-*-0');

    expect(parseZikrDayInput(' 09-09 '), '09-09');
    expect(parseZikrDayInput(' 09-09, , 10-*-0 '), ['09-09', '10-*-0']);
    expect(parseZikrDayInput(' , '), isNull);
  });

  test('order helpers accept blank, signed, and decimal numbers', () {
    expect(isValidZikrOrderInput(''), isTrue);
    expect(isValidZikrOrderInput('-2'), isTrue);
    expect(isValidZikrOrderInput('5.5'), isTrue);
    expect(isValidZikrOrderInput('five'), isFalse);
    expect(isValidZikrOrderInput('1.'), isFalse);

    expect(formatZikrOrderValue(null), '');
    expect(formatZikrOrderValue(5.0), '5');
    expect(formatZikrOrderValue(5.25), '5.25');
  });

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
