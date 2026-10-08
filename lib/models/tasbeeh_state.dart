/// The Tasbeeh counter's two ways of counting (docs/DESIGN_SPEC.md, "Tools").
enum TasbeehMode {
  /// Guided Tasbih al-Zahra: 34 Allahu Akbar, 33 Alhamdulillah, 33
  /// SubhanAllah.
  zahra,

  /// An open-ended count, marking the user's own targets.
  free,
}

/// One phrase of Tasbih al-Zahra and how many times it is said.
class ZahraPhase {
  const ZahraPhase({
    required this.arabic,
    required this.size,
    required this.start,
  });

  final String arabic;
  final int size;

  /// How many counts come before this phase.
  final int start;

  int get end => start + size;
}

/// Tasbih al-Zahra's three phases, in order.
const List<ZahraPhase> zahraPhases = [
  ZahraPhase(arabic: 'اَللّٰهُ اَكْبَرُ', size: 34, start: 0),
  ZahraPhase(arabic: 'اَلْحَمْدُ لِلّٰهِ', size: 33, start: 34),
  ZahraPhase(arabic: 'سُبْحَانَ اللّٰهِ', size: 33, start: 67),
];

/// The whole of Tasbih al-Zahra.
const int zahraTotal = 100;

/// Where a Tasbih al-Zahra count stands: which phrase, and how far into it.
class ZahraProgress {
  const ZahraProgress(this.count) : assert(count >= 0);

  final int count;

  bool get isComplete => count >= zahraTotal;

  /// The phrase being said; the last one once complete.
  int get phaseIndex {
    for (var i = 0; i < zahraPhases.length; i++) {
      if (count < zahraPhases[i].end) return i;
    }
    return zahraPhases.length - 1;
  }

  ZahraPhase get phase => zahraPhases[phaseIndex];

  /// How many of the current phrase have been said.
  int get countInPhase => count - phase.start;

  /// How full phase [index]'s bar is, 0 to 1.
  double fillOf(int index) {
    final phase = zahraPhases[index];
    return ((count - phase.start) / phase.size).clamp(0.0, 1.0);
  }

  /// Whether reaching [count] ends a phrase: 34, 67 and 100.
  static bool isTarget(int count) =>
      zahraPhases.any((phase) => phase.end == count);
}

/// The default targets of a free count: every hundred, up to three hundred.
const List<int> defaultFreeTargets = [100, 200, 300];

/// The next of [targets] a free count of [count] has still to reach, or
/// null when it has passed them all.
int? nextFreeTarget(int count, List<int> targets) {
  final ahead = targets.where((target) => target > count).toList()..sort();
  return ahead.isEmpty ? null : ahead.first;
}
