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

  /// The rakaat being prayed, as the counter shows it: once both sajdahs of
  /// a rakaat are done the next one has begun ("Rakaat 2 of 4, 0 of 2
  /// sajdahs"); the last one once complete.
  int get currentRakaat =>
      isComplete ? totalRakaat : (completedSajdahs ~/ 2) + 1;

  /// Sajdahs done in [currentRakaat]: 0 or 1, and 2 once complete.
  int get sajdahsInCurrentRakaat => isComplete ? 2 : completedSajdahs % 2;

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
