import 'package:flutter_test/flutter_test.dart';
import 'package:shia_companion/models/prayer_counter_state.dart';

void main() {
  test('counter maps sajdahs to the expected rakaat and sajdah', () {
    var state = const PrayerCounterState(totalRakaat: 4);

    expect(state.displayValue, '1.–');
    expect(state.rakaat, 1);
    expect(state.sajdah, 0);

    state = state.recordSajdah();
    expect(state.displayValue, '1.1');

    state = state.recordSajdah();
    expect(state.displayValue, '1.2');

    state = state.recordSajdah();
    expect(state.displayValue, '2.1');
  });

  test('counter stops at the final sajdah', () {
    var state = const PrayerCounterState(totalRakaat: 2);

    for (var index = 0; index < 5; index++) {
      state = state.recordSajdah();
    }

    expect(state.completedSajdahs, 4);
    expect(state.displayValue, '2.2');
    expect(state.isComplete, isTrue);
  });

  test('undo and reset keep the state within bounds', () {
    var state = const PrayerCounterState(totalRakaat: 3).undoSajdah();
    expect(state.completedSajdahs, 0);

    state = state.recordSajdah().recordSajdah().undoSajdah();
    expect(state.displayValue, '1.1');

    state = state.reset(totalRakaat: 4);
    expect(state.totalRakaat, 4);
    expect(state.completedSajdahs, 0);
  });
}
