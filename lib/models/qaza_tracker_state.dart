enum QazaEntryType {
  fajr,
  dhuhr,
  asr,
  maghrib,
  isha,
  ayat,
  fast,
}

extension QazaEntryTypeInfo on QazaEntryType {
  String get key => switch (this) {
        QazaEntryType.fajr => 'fajr',
        QazaEntryType.dhuhr => 'dhuhr',
        QazaEntryType.asr => 'asr',
        QazaEntryType.maghrib => 'maghrib',
        QazaEntryType.isha => 'isha',
        QazaEntryType.ayat => 'namaz_e_ayat',
        QazaEntryType.fast => 'fast',
      };

  String get label => switch (this) {
        QazaEntryType.fajr => 'Fajr',
        QazaEntryType.dhuhr => 'Dhuhr',
        QazaEntryType.asr => 'Asr',
        QazaEntryType.maghrib => 'Maghrib',
        QazaEntryType.isha => 'Isha',
        QazaEntryType.ayat => 'Namaz e Ayat',
        QazaEntryType.fast => 'Fasts',
      };

  bool get isPrayer => this != QazaEntryType.fast;
}

QazaEntryType? qazaEntryTypeFromKey(String key) {
  for (final type in QazaEntryType.values) {
    if (type.key == key) return type;
  }
  return null;
}

class QazaEntryCount {
  const QazaEntryCount({
    this.remaining = 0,
    this.completed = 0,
  });

  static const zero = QazaEntryCount();

  final int remaining;
  final int completed;

  bool get isEmpty => remaining == 0 && completed == 0;

  int get total => remaining + completed;

  QazaEntryCount copyWith({
    int? remaining,
    int? completed,
  }) {
    return QazaEntryCount(
      remaining: _nonNegative(remaining ?? this.remaining),
      completed: _nonNegative(completed ?? this.completed),
    );
  }

  QazaEntryCount plus(QazaEntryCount other) {
    return QazaEntryCount(
      remaining: remaining + other.remaining,
      completed: completed + other.completed,
    );
  }

  QazaEntryCount applyDelta(QazaEntryDelta delta) {
    return QazaEntryCount(
      remaining: _nonNegative(remaining + delta.remaining),
      completed: _nonNegative(completed + delta.completed),
    );
  }

  Map<String, int> toJson() => {
        'remaining': remaining,
        'completed': completed,
      };

  static QazaEntryCount fromJson(dynamic value) {
    if (value is! Map) return zero;
    return QazaEntryCount(
      remaining: _readInt(value['remaining']),
      completed: _readInt(value['completed']),
    );
  }
}

class QazaEntryDelta {
  const QazaEntryDelta({
    this.remaining = 0,
    this.completed = 0,
  });

  static const zero = QazaEntryDelta();

  final int remaining;
  final int completed;

  bool get isZero => remaining == 0 && completed == 0;

  QazaEntryDelta plus(QazaEntryDelta other) {
    return QazaEntryDelta(
      remaining: remaining + other.remaining,
      completed: completed + other.completed,
    );
  }

  QazaEntryDelta minus(QazaEntryDelta other) {
    return QazaEntryDelta(
      remaining: remaining - other.remaining,
      completed: completed - other.completed,
    );
  }

  QazaEntryDelta inverse() {
    return QazaEntryDelta(
      remaining: -remaining,
      completed: -completed,
    );
  }

  Map<String, int> toJson() => {
        'remaining': remaining,
        'completed': completed,
      };

  static QazaEntryDelta fromJson(dynamic value) {
    if (value is! Map) return zero;
    return QazaEntryDelta(
      remaining: _readSignedInt(value['remaining']),
      completed: _readSignedInt(value['completed']),
    );
  }
}

class QazaTrackerDelta {
  QazaTrackerDelta([Map<QazaEntryType, QazaEntryDelta>? deltas])
      : deltas = Map.unmodifiable(_sanitizeDeltas(deltas ?? const {}));

  factory QazaTrackerDelta.single(
    QazaEntryType type,
    QazaEntryDelta delta,
  ) {
    return QazaTrackerDelta({type: delta});
  }

  factory QazaTrackerDelta.between(
    QazaTrackerState previous,
    QazaTrackerState next,
  ) {
    return QazaTrackerDelta({
      for (final type in QazaEntryType.values)
        type: QazaEntryDelta(
          remaining:
              next.countFor(type).remaining - previous.countFor(type).remaining,
          completed:
              next.countFor(type).completed - previous.countFor(type).completed,
        ),
    });
  }

  factory QazaTrackerDelta.fromJson(dynamic value) {
    if (value is! Map) return QazaTrackerDelta.zero;
    return QazaTrackerDelta({
      for (final entry in value.entries)
        if (qazaEntryTypeFromKey(entry.key.toString()) != null)
          qazaEntryTypeFromKey(entry.key.toString())!:
              QazaEntryDelta.fromJson(entry.value),
    });
  }

  static final zero = QazaTrackerDelta();

  final Map<QazaEntryType, QazaEntryDelta> deltas;

  bool get isZero => deltas.isEmpty;

  QazaEntryDelta deltaFor(QazaEntryType type) {
    return deltas[type] ?? QazaEntryDelta.zero;
  }

  QazaTrackerDelta plus(QazaTrackerDelta other) {
    return QazaTrackerDelta({
      for (final type in QazaEntryType.values)
        type: deltaFor(type).plus(other.deltaFor(type)),
    });
  }

  QazaTrackerDelta minus(QazaTrackerDelta other) {
    return QazaTrackerDelta({
      for (final type in QazaEntryType.values)
        type: deltaFor(type).minus(other.deltaFor(type)),
    });
  }

  Map<String, Map<String, int>> toJson() => {
        for (final entry in deltas.entries) entry.key.key: entry.value.toJson(),
      };

  static Map<QazaEntryType, QazaEntryDelta> _sanitizeDeltas(
    Map<QazaEntryType, QazaEntryDelta> source,
  ) {
    return {
      for (final entry in source.entries)
        if (!entry.value.isZero) entry.key: entry.value,
    };
  }
}

class QazaTrackerState {
  QazaTrackerState([Map<QazaEntryType, QazaEntryCount>? entries])
      : entries = Map.unmodifiable({
          for (final type in QazaEntryType.values)
            type: entries?[type] ?? QazaEntryCount.zero,
        });

  factory QazaTrackerState.fromJson(dynamic value) {
    if (value is! Map) return QazaTrackerState.empty;
    return QazaTrackerState({
      for (final entry in value.entries)
        if (qazaEntryTypeFromKey(entry.key.toString()) != null)
          qazaEntryTypeFromKey(entry.key.toString())!:
              QazaEntryCount.fromJson(entry.value),
    });
  }

  static final empty = QazaTrackerState();

  final Map<QazaEntryType, QazaEntryCount> entries;

  bool get isEmpty => entries.values.every((entry) => entry.isEmpty);

  int get totalRemaining =>
      entries.values.fold(0, (sum, entry) => sum + entry.remaining);

  int get totalCompleted =>
      entries.values.fold(0, (sum, entry) => sum + entry.completed);

  QazaEntryCount countFor(QazaEntryType type) {
    return entries[type] ?? QazaEntryCount.zero;
  }

  QazaTrackerState setCount(QazaEntryType type, QazaEntryCount count) {
    return QazaTrackerState({
      ...entries,
      type: count,
    });
  }

  QazaTrackerState plus(QazaTrackerState other) {
    return QazaTrackerState({
      for (final type in QazaEntryType.values)
        type: countFor(type).plus(other.countFor(type)),
    });
  }

  QazaTrackerState applyDelta(QazaTrackerDelta delta) {
    if (delta.isZero) return this;
    return QazaTrackerState({
      for (final type in QazaEntryType.values)
        type: countFor(type).applyDelta(delta.deltaFor(type)),
    });
  }

  Map<String, Map<String, int>> toJson() => {
        for (final entry in entries.entries)
          entry.key.key: entry.value.toJson(),
      };
}

int _readInt(dynamic value) => _nonNegative(_readSignedInt(value));

int _readSignedInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int _nonNegative(int value) => value < 0 ? 0 : value;
