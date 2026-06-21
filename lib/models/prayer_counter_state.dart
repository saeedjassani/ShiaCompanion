import 'dart:math' as math;

class PrayerCounterState {
  const PrayerCounterState({
    required this.totalRakaat,
    this.completedSajdahs = 0,
  })  : assert(totalRakaat > 0),
        assert(completedSajdahs >= 0),
        assert(completedSajdahs <= totalRakaat * 2);

  final int totalRakaat;
  final int completedSajdahs;

  int get totalSajdahs => totalRakaat * 2;

  bool get hasStarted => completedSajdahs > 0;

  bool get isComplete => completedSajdahs == totalSajdahs;

  int get rakaat {
    if (!hasStarted) return 1;
    return math.min(((completedSajdahs - 1) ~/ 2) + 1, totalRakaat);
  }

  int get sajdah {
    if (!hasStarted) return 0;
    return ((completedSajdahs - 1) % 2) + 1;
  }

  String get displayValue => '$rakaat.${sajdah == 0 ? '–' : sajdah}';

  PrayerCounterState recordSajdah() {
    if (isComplete) return this;
    return PrayerCounterState(
      totalRakaat: totalRakaat,
      completedSajdahs: completedSajdahs + 1,
    );
  }

  PrayerCounterState undoSajdah() {
    if (!hasStarted) return this;
    return PrayerCounterState(
      totalRakaat: totalRakaat,
      completedSajdahs: completedSajdahs - 1,
    );
  }

  PrayerCounterState reset({int? totalRakaat}) {
    return PrayerCounterState(totalRakaat: totalRakaat ?? this.totalRakaat);
  }
}
